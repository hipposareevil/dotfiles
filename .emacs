(setq mac-option-modifier 'super )
 (setq mac-command-modifier 'meta )


(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(custom-enabled-themes (quote (tango-dark)))
 '(custom-safe-themes (quote ("d677ef584c6dfc0697901a44b885cc18e206f05114c8a3b7fde674fce6180879" "8aebf25556399b58091e533e455dd50a6a9cba958cc4ebb0aab175863c25b9a4" "e16a771a13a202ee6e276d06098bc77f008b73bbac4d526f160faa2d76c1dd0e" "989b6cb60e97759d7c45d65121f43b746aff298b5cf8dcf5cfd19c03830b83e9" "54266114287ef8abeda6a3df605deffe777957ba994750da6b8595fe90e932f0" default)))
 '(ring-bell-function (quote ignore) t))
(setq visible-bell t)
(setq max-specpdl-size 2000)

(setq redisplay-dont-pause t)

(setq global-font-lock-mode "true")
(display-time)

;; Shell stuff
(setq binary-process-input t) 
(setq shell-file-name "bash")
(setenv "SHELL" shell-file-name) 
(setq explicit-shell-file-name shell-file-name) 
(setq explicit-sh-args '("-login" "-i"))

;; Window frame stuff
(setq default-frame-alist
                '((top . 100) (left . 120)
                  (width . 220) (height . 80)
                  (cursor-color . "Orchid")
		  (pointer-color . "Orchid")
		  (border-color . "white")
                  (cursor-type . box)
                  (foreground-color . "white")
                  (background-color . "#292172")
		  ))

(setq initial-frame-alist '((top . 30) (left . 10)))

;; Colors
(cond ((fboundp 'global-font-lock-mode)
            ;; Customize face attributes
            (setq font-lock-face-attributes
                  ;; Symbol-for-Face Foreground Background Bold Italic Underline
                  '((font-lock-comment-face       "OrangeRed")
                    (font-lock-builtin-face       "DarkSteelBlue")
                    (font-lock-string-face        "lightsalmon")
		    (font-lock-function-name-face "LightSteelBlue")
                    (font-lock-keyword-face       "Cyan")
                    (font-lock-variable-name-face "LightGoldenRod")
                    (font-lock-type-face          "PaleGreen")
		    (font-lock-constant-face	  "aquamarine")
                    ))
            ;; Load the font-lock package.
            (require 'font-lock)
            ;; Maximum colors
            (setq font-lock-maximum-decoration t)
            ;; Turn on font-lock in all modes that support it
            (global-font-lock-mode t)))




(defconst my-c-style
  '((c-tab-always-indent        . t)
    (c-comment-only-line-offset . 0)
    (c-hanging-braces-alist     . ((substatement-open after)
				   (brace-list-open)))
    (c-hanging-colons-alist     . ((member-init-intro before)
				   (inher-intro)
				   (case-label after)
				   (label after)
				   (access-label after)))
    (c-cleanup-list             . (scope-operator
				   empty-defun-braces
				   defun-close-semi))
    (c-offsets-alist            . ((arglist-close . c-lineup-arglist)
				   (substatement-open . 0)
				   (case-label        . 2)
				   (inline-open       . 0)
				   (block-open        . 0)
				   (statement-cont    . ++)
				   (knr-argdecl-intro . -)))
;;    (c-echo-syntactic-information-p . t)
    )
  "My C Programming Style")

;; Customizations for all of c-mode, c++-mode, and objc-mode
(defun my-c-mode-common-hook ()
  ;; add my personal style and set it for the current buffer
  (c-add-style "PERSONAL" my-c-style t)
  (setq c-basic-offset 2)  
  (c-set-offset 'substatement-open 0)
  ;; offset customizations not in my-c-style
  (c-set-offset 'member-init-intro 0)

  ;; other customizations
  (setq tab-width 2
	;; this will make sure spaces are used instead of tabs
	indent-tabs-mode nil)
  ;; we like auto-newline and hungry-delete
;;  (c-toggle-auto-hungry-state 0)

  ;; keybindings for all supported languages.  We can put these in
  ;; c-mode-base-map because c-mode-map, c++-mode-map, objc-mode-map,
  ;; java-mode-map, and idl-mode-map inherit from it.
  (define-key c-mode-base-map "\C-m" 'newline-and-indent)
  )
     
(add-hook 'c-mode-common-hook 'my-c-mode-common-hook)




(global-set-key [f3] 'undo)
(global-set-key [f4] 'replace-string)
(global-set-key [f5] 'query-replace)
(global-set-key [f6] 'isearch-forward-regexp)
(global-set-key [f7] 'isearch-backward-regexp)
(global-set-key [f8] 'replace-regexp)
(global-set-key [f9] 'goto-line)

(global-set-key (kbd "C-x g") 'insert-register)
(global-set-key (kbd "C-x x") 'copy-to-register)

(global-set-key "\M-n" (lambda() (interactive) (scroll-up 1)))
(global-set-key "\M-p" (lambda() (interactive) (scroll-down 1)))


;;(custom-set-variables
;; '(auto-save-interval 10000))
;;(custom-set-faces)

(setenv "PATH" (concat "/usr/local/bin" path-separator (getenv "PATH")))
(setenv "PATH" (concat "/Users/sami/crypt" path-separator (getenv "PATH")))
(setq exec-path (append exec-path '("/usr/local/bin")))
(setq exec-path (append exec-path '("/Users/sami/crypt")))

(setq load-path (cons "/Users/sami/crypt" load-path))
(require 'ps-ccrypt "ps-ccrypt.el")

;; for loading packages like markdown
(require 'package)
(add-to-list 'package-archives 
    '("marmalade" .
      "http://marmalade-repo.org/packages/"))
(package-initialize)

;; markdown
(autoload 'markdown-mode "markdown-mode"
   "Major mode for editing Markdown files" t)
(add-to-list 'auto-mode-alist '("\\.markdown\\'" . markdown-mode))
(add-to-list 'auto-mode-alist '("\\.md\\'" . markdown-mode))



;; themes
(add-to-list 'custom-theme-load-path "~/.emacs.d/themes")
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )


(setq command-line-default-directory "~/")
(server-start)
(remove-hook 'kill-buffer-query-functions 'server-kill-buffer-query-function)
