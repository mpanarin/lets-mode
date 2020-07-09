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
;; machinery (TODO) for running the tasks themselves

;;; Code:

(require 'cl-lib)
(require 'yaml-mode)
(require 'company)

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
  (cl-case command
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
(define-derived-mode lets-mode yaml-mode "Lets config"
  "Toggle lets mode locally in the buffer.")

;;;###autoload
(add-to-list 'auto-mode-alist '("lets\.?.*\.ya?ml" . lets-mode))

(provide 'lets-mode)
