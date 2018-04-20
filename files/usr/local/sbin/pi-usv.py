#!/usr/bin/python
# -----------------------------------------------------------------------------
# Main script of system-service pi-usv. It reads the queue of the
# gpio-poll-service and acts on gpio-events.
#
# Author: Bernhard Bablok
# License: GPL3
#
# Website: https://github.com/bablokb/pi-usv
#
# -----------------------------------------------------------------------------

import os, sys, datetime, time, signal, syslog, traceback, select
import ConfigParser, threading

FIFO_NAME     = "/var/run/gpio-poll.fifo"
POLL_INTERVAL = 5

# --- states   ----------------------------------------------------------------

STATE_OK    = 'O'
STATE_WARN  = 'W'
STATE_CRIT  = 'C'
STATE_SDOWN = 'S'

# transitions: tuple is: (current-state,GP-of-PIC,value) -> next-state
#              once we reached SDOWN, we initiate shutdown and quit

STRANS = {
  (STATE_OK,4,0): None,            # ignore, GPIO-error
  (STATE_OK,4,1): STATE_CRIT,      # only possible if turned on in this state
  (STATE_OK,5,0): None,            # ignore, GPIO-error
  (STATE_OK,5,1): STATE_WARN,

  (STATE_WARN,4,0): None,          # ignore, GPIO-error
  (STATE_WARN,4,1): STATE_CRIT,
  (STATE_WARN,5,0): STATE_OK,      # voltage reached sane state again
  (STATE_WARN,5,1): None,          # ignore, GPIO-error

  (STATE_CRIT,4,0): STATE_WARN,    # voltage reached warn-state again
  (STATE_CRIT,4,1): None,          # ignore, GPIO-error
  (STATE_CRIT,5,0): STATE_SDOWN,
  (STATE_CRIT,5,1): None           # ignore, GPIO-error
  }

# --- class definition   ------------------------------------------------------

class Usv(object):
  """ class for systemd-service pi-usv """

  # --- constructor   ---------------------------------------------------------

  def __init__(self):
    """ constructor """

    # preliminary settings, will be changed soon
    self._debug = True
    self._foreground = True
    self._stop_event = threading.Event()

  # --- read configuration   --------------------------------------------------

  def read_config(self):
     """ read configuration """

     parser = ConfigParser.RawConfigParser()
     parser.read('/etc/pi-usv.conf')

     self._debug = parser.getboolean("GLOBAL", "debug")
     self.debug("DEBUG","debug: %r" % self._debug)

     # GPIO to GP mapping
     self._gp4   = parser.getint("GPIO", "GP4")
     self._gp5   = parser.getint("GPIO", "GP5")
     self.debug("DEBUG","GP4: %r, GP5: %r" % (self._gp4,self._gp5))

     # state-hooks
     self._hooks = {}
     for hook in ['ok','warn','crit','shutdown']:
       try:
         hook_name = parser.get("HOOK", hook)
         self._hooks[hook[0].upper()] = hook_name
         self.debug("DEBUG","hook for %s: %s" % (hook,hook_name))
       except:
         self._hooks[hook[0].upper()] = None

     # map GPIO-numbers to GP-numbers
     self._gpiomap = {self._gp4: 4, self._gp5: 5}
     self.debug("DEBUG","map: %r" % self._gpiomap)

  # --- initialization   ------------------------------------------------------

  def init(self):
    """ initialization after read_config """

    try:
      self._foreground = os.getpgrp() == os.tcgetpgrp(sys.stdout.fileno())
    except:
      self._foreground = False

    if self._debug and not self._foreground:
      syslog.openlog("pi-usv")

  # --- write debug-message to system log   -----------------------------------

  def debug(self,level,msg):
    """ write debug-message to system-log """

    if self._debug:
      if self._foreground:
        now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        text = "[%s] [%s] %s\n" % (level,now,msg)
        sys.stderr.write(text)
        sys.stderr.flush()
      else:
        syslog.syslog(msg)

  # --- setup signal handler   ------------------------------------------------

  def signal_handler(self,_signo, _stack_frame):
    """ signal-handler to cleanup things """

    self._stop_event.set()
    sys.exit(0)

  # --- initiate shutdown   ---------------------------------------------------

  def _shutdown(self):
    """ initiate shutdown (not executed if a shutdown-hook is defined) """

    self.debug("INFO","processing shutdown")
    if not self._debug:
      try:
        os.system("sudo /sbin/halt &")
      except:
        pass
    else:
      self.debug("WARNING","no shutdown in debug-mode")

  # --- read and process GPIO-events   ----------------------------------------

  def poll_events(self):
    """ read GPIO-events from pipe """

    state = STATE_OK

    # wait for pipe
    pipe_wait = 0.5
    while not os.path.exists(FIFO_NAME):
      if pipe_wait < POLL_INTERVAL/2:
        pipe_wait *= 2
      self.debug("DEBUG","waiting for pipe")
      if self._stop_event.wait(pipe_wait):
        self.debug("DEBUG", "terminating program")
        return

    # make sure the open call does not block
    p_fd = os.open(FIFO_NAME,os.O_RDONLY|os.O_NONBLOCK)
    pipe = os.fdopen(p_fd,"r")
    poll_obj = select.poll()
    poll_obj.register(p_fd,select.POLLPRI|select.POLLIN)

    while True:
      self.debug("DEBUG", "polling pipe ...")
      poll_result = poll_obj.poll(POLL_INTERVAL*1000)
      for (fd,event) in poll_result:
        # do some sanity checks
        if event & select.POLLHUP == select.POLLHUP:
          self.debug("DEBUG", "POLLHUP received")
          # we just wait and hope the gpio-manager comes back
          if self._stop_event.wait(POLL_INTERVAL):
            break
          continue

        line = pipe.readline()
        [gpio,value,stime,rtime] = line.split(" ")
        state = self._process_event(state,int(gpio),int(value))
      if self._stop_event.wait(0.01):
        break

    poll_obj.unregister(pipe)
    self.debug("DEBUG","no more events, stopping program")
  
  # --- process GPIO-events   -------------------------------------------------

  def _process_event(self,state,gpio,value):
    """ process GPIO-events """

    if self._gpiomap.has_key(gpio):
      self.debug("DEBUG","mapping gpio %d" % gpio)
      gp = self._gpiomap[gpio]
    else:
      self.debug("ERROR","received invalid GPIO %d" % gpio)
      return state

    key = (state,gp,value)
    if STRANS.has_key(key):
      next_state = STRANS[key]
    else:
      self.debug("ERROR","undefined transition: %r" % (key,))
      return state

    self.debug("DEBUG","next state: %s" % next_state)
    if not next_state:
      self.debug("ERROR","next state is undefined, ignoring event")
      return state

    # process state-hook
    hook_name = self._hooks[next_state]
    if hook_name:
      # execute hook
      self.debug("INFO","executing: %s" % hook_name)
      os.system("%s &" % hook_name)
    elif next_state == STATE_SDOWN:
      # N.B: will be skipped if we have a shutdown-hook
      self.debug("INFO","initializing shutdown")
      self._shutdown()
    else:
      # no hook defined, so ignore event
      self.debug("INFO","no hook to execute for %s" % next_state)

    # return state
    return next_state

# --- main program   ----------------------------------------------------------

if __name__ == '__main__':

  # create object, and read configuration
  usv = Usv()
  usv.read_config()
  usv.init()
  
  # setup signal-handler
  signal.signal(signal.SIGTERM, usv.signal_handler)
  signal.signal(signal.SIGINT,  usv.signal_handler)

  # start polling
  usv.poll_events()
