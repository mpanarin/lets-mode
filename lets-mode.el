;;; lets-mode --- Emacs major-mode for editing lets config files -*- lexical-binding: t -*-

;; Copyright (C) 2020 Panarin Mykhailo

;; Author: Panarin Mykhailo <mykhailopanarin@gmail.com>
;; Created: 9 jul 2020
;; Version: 0.1.0
;; Keywords: notification alert org org-agenda agenda

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This is a major-mode for editing lets config files
;; It provides a completion backend as well as the
;; machinery for running the tasks themselves

;;; Code:

(require 'cl-lib)
(require 'yaml-mode)
(require 's)
(require 'ansi-color)
;; completion
(require 'company)
;; running
(require 'compile)
(require 'helm)
(require 'magit-popup)

(defgroup lets-mode nil
  "Lets task runner mode."
  :group 'tools)

(defcustom lets-command "lets"
  "Command to run lets."
  :type 'string
  :group 'lets-mode)

(defconst top-level-keywords '("shell"
                               "commands"
                               "env"
                               "eval_env"
                               "version"
                               "mixins"))

(defconst command-level-keywords '("description"
                                   "env"
                                   "eval_env"
                                   "options"
                                   "checksum"
                                   "persist_checksum"
                                   "cmd"
                                   "depends"))

(defconst lets-compilation-buffer "*Lets command: %s*")

(defun lets-compilation-filter ()
  "Filter function for compilation output."
  (ansi-color-apply-on-region compilation-filter-start (point-max)))

(define-compilation-mode lets-compilation-mode "Lets"
  "Lets compilation mode."
  (add-hook 'compilation-filter-hook 'lets-compilation-filter nil t)
  )

(defun lets-mode--filter-out-lets-result (lines)
  "filters out the result of lets command to get proper candidates."
  (let* ((strippedlines (-->
                (mapcar #'ansi-color-apply lines)
                (mapcar #'s-trim it)))
         (start (-elem-index "Available Commands:" strippedlines))
         (end (-elem-index "Flags:" strippedlines)))
    (cond
     ((and start end) (-slice strippedlines (+ start 1) end))
     (t strippedlines)))
  )

(defun lets-mode--collect-helm-candidates ()
  "Collecting candidates for `helm'."
  (let* ((lets-res (s-lines (shell-command-to-string "lets")))
         (candidates (lets-mode--filter-out-lets-result lets-res)))
    (cond
     ;; Do nothing if this is an error
     ((string-prefix-p "[ERROR]" (car candidates) t) candidates)
     ;; parse the results of lets command
     (t candidates))))

(defun lets-mode--run-task (candidate)
  (cond
   ;; Do nothing if this is an error
   ((string-prefix-p "[ERROR]" candidate t) candidate)
   ;; run the task in compilation buffer
   (t
    (let* ((task (car (s-split-up-to " " (s-trim candidate) 1 t)))
           (lets-buffer (format lets-compilation-buffer task)))
      (progn
        (when (get-buffer lets-buffer)
          (kill-buffer lets-buffer))
        (with-current-buffer (get-buffer-create lets-buffer)
          (compilation-start (s-join " " `(,lets-command ,task)) 'lets-compilation-mode (lambda (_) (buffer-name))))
        )
      ))))

(defun lets-mode-current-yaml-level ()
  "Calculate current yaml level"
  (/ (current-indentation) yaml-indent-offset))

(defun lets-mode-get-completion-candidates (arg)
  "Returns a completion candidate for `lets-mode'.
Currently it is very naive and calculates indentation level to show proper completions."
  (cl-remove-if-not
   (lambda (cand) (string-prefix-p arg cand))
   (case (lets-mode-current-yaml-level)
     (0 top-level-keywords)
     (2 command-level-keywords)))
  )

(defun lets-mode-company-backend (command &optional arg &rest ignored)
  "`company-mode' completion back-end for Lets."
  (interactive (list 'interactive))
  (case command
    (interactive (company-begin-backend 'lets-mode-company-backend))
    (prefix (and (eq major-mode 'lets-mode)
                 (company-grab-symbol)))
    (candidates (lets-mode-get-completion-candidates arg))
    )
  )

(add-hook 'lets-mode-hook
          (lambda ()
            (add-to-list (make-local-variable 'company-backends)
                         'lets-mode-company-backend)))

;;;###autoload
(defun lets-mode-run-task ()
  "Run Lets task."
  (interactive)
  (helm
   :buffer "*Helm Run Lets Task*"
   :sources (helm-build-sync-source "Lets tasks:"
              :candidates (lets-mode--collect-helm-candidates)
              :action '(("Run task" . lets-mode--run-task))
              ))
  )

;;;###autoload
(define-derived-mode lets-mode yaml-mode "Lets config"
  "Toggle lets mode locally in the buffer.")

;;;###autoload
(add-to-list 'auto-mode-alist '("lets\.?.*\.ya?ml" . lets-mode))

(provide 'lets-mode)
