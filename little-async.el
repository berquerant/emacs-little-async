;;; little-async.el --- Little things async -*- lexical-binding: t -*-

;; Copyright (C) 2021 berquerant

;; Author: berquerant
;; Maintainer: berquerant
;; Package-Requires: ((cl-lib "1.0"))
;; Created: 19 Apr 2021
;; Version: 0.1.1
;; Keywords: async
;; URL: https://github.com/berquerant/emacs-little-async

;; This file is NOT part of GNU Emacs.

;;; License:

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or (at
;; your option) any later version.

;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:

;; Please see README.md from the same repository for documentation.

;;; Code:

(require 'cl-lib)

(defgroup little-async nil
  "Little things async.")

(defcustom little-async-start-process-buffer-name "*little-async-start-process*"
  "Buffer name of the buffer to associate with the spawned process by `little-async-start-process'."
  :group 'little-async
  :type 'string
  :version "27.2")

(defcustom little-async-start-process-process-name "little-async-start-process-process"
  "Process name of the spawned process by `little-async-start-process'."
  :group 'little-async
  :type 'string
  :version "27.2")

(defcustom little-async-start-process-sentinel-buffer-name "*little-async-start-process-sentinel*"
  "Buffer name of the buffer to accept `little-async-default-process-sentinel' output."
  :group 'little-async
  :type 'string
  :version "27.2")

(defcustom little-async-quiet nil
  "Do not write log to `little-async-start-process-buffer-name' buffer if t."
  :group 'little-async
  :type 'boolean
  :version "27.2")

(defcustom little-async-default-start-process-timeout 10000
  "Timeout milliseconds of `little-async-start-process'."
  :group 'little-async
  :type 'integer
  :version "27.2")

(defcustom little-async-default-start-process-process-sentinel 'little-async--default-process-sentinel
  "Process sentinel of the spawned process by `little-async-start-process'."
  :group 'little-async
  :type 'function
  :version "27.2")

(defcustom little-async-default-start-process-timeout-hook 'little-async--default-timeout-hook
  "Timeout hook of the spawned process by `little-async-start-process'."
  :group 'little-async
  :type 'function
  :version "27.2")

(defun little-async--to-datetime (&optional time zone)
  "Convert TIME (timestamp) in ZONE (timezone) into string.
default TIME is now, ZONE is here."
  (format-time-string "%F %T"
                      (or time (current-time))
                      (or zone (current-time-zone))))

(defun little-async--invoke-after (duration hook)
  "Invoke HOOK after DURATION seconds.
DURATION is not negative, HOOK has no arguments."
  (run-at-time (or (and (>= duration 0) duration) 0)
               nil hook))

(defun little-async--describe-process (process)
  "Convert PROCESS into readable string."
  (format "%s (pid: %d, status: %s) %s"
          (process-name process)
          (process-id process)
          (symbol-name (process-status (process-name process)))
          (process-command process)))

(defun little-async--insert-buffer (buffer input)
  "Insert INPUT into BUFFER if not `little-async-quiet'."
  (unless little-async-quiet
    (with-current-buffer buffer
      (goto-char (point-max))
      (insert input))))

(defun little-async--default-process-sentinel (process event)
  "Insert PROCESS and EVENT into buffer `little-async-start-process-sentinel-buffer-name'."
  (little-async--insert-buffer (get-buffer-create little-async-start-process-sentinel-buffer-name)
                               (format "%s Process: `%s' had the event `%s'.\n"
                                       (little-async--to-datetime)
                                       (little-async--describe-process process)
                                       event))
  (let ((pb (process-buffer process)))
    (when (buffer-name pb)
      (little-async--insert-buffer pb
                                   (format "%s FINISHED PROCESS: `%s'.\n"
                                           (little-async--to-datetime)
                                           (little-async--describe-process process))))
    (display-buffer pb)))

(defun little-async--default-timeout-hook (pname)
  "Kill process of PNAME if active yet."
  (let ((s (process-status pname)))
    (when (and s (not (eq s 'exit)))
      (message "%s Process: `%s' killed due to timeout."
               (little-async--to-datetime)
               (little-async--describe-process (get-process pname)))
      (kill-process pname))))

(cl-defun little-async--make-process (command &key process-name buffer-name timeout timeout-hook filter sentinel)
  "Start process with timeout and return the process.

COMMAND to be executed.
PROCESS-NAME is the (base) name of the spawned process.  Default is `little-async-start-process-process-name'.
BUFFER-NAME is the name of the buffer to associate with the spawned process.  Default is `little-async-start-process-buffer-name'.
TIMEOUT is TTL of the process (milliseconds).  Default is `little-async-default-start-process-timeout'.
TIMEOUT-HOOK is invoked if timeout occurs.  Default is `little-async-default-start-process-timeout-hook'.
FILTER is process filter.
SENTINEL is process sentinel.  Default is `little-async-default-start-process-process-sentinel'.

See `start-process-shell-command'."
  (let ((p (start-process-shell-command (or process-name little-async-start-process-process-name)
                                        (or buffer-name little-async-start-process-buffer-name)
                                        command))
        (s (or sentinel little-async-default-start-process-process-sentinel))
        (td (/ (or timeout little-async-default-start-process-timeout) 1000.0))
        (th (or timeout-hook little-async-default-start-process-timeout-hook)))
    (when th
      (little-async--invoke-after td `(lambda () (,th ,(process-name p)))))
    (when s
      (set-process-sentinel p s))
    (when filter
      (set-process-filter p filter))
    (little-async--insert-buffer (get-buffer-create little-async-start-process-sentinel-buffer-name)
                                 (format "%s Process: `%s' started.\n"
                                         (little-async--to-datetime)
                                         (little-async--describe-process p)))
    p))

;;;###autoload
(cl-defun little-async-start-process (command &key input process-name buffer-name timeout timeout-hook filter sentinel)
  "Start process.

INPUT is input string of COMMAND.
See `little-async--make-process'."
  (let ((p (little-async--make-process command
                                       :process-name process-name
                                       :buffer-name buffer-name
                                       :timeout timeout
                                       :timeout-hook timeout-hook
                                       :filter filter
                                       :sentinel sentinel)))
    (when input
      (process-send-string p input)
      (when (not (string-match-p "\n$" input))
        (process-send-string p "\n"))
      (process-send-eof p))
    p))

(provide 'little-async)
;;; little-async.el ends here
