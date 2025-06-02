;;; bible-gateway.el --- A Simple BibleGateway Client -*- lexical-binding: t -*-

;; Copyright (C) 2025 Kristjon Ciko

;; Author: Kristjon Ciko
;; Keywords: convenience comm hypermedia
;; Homepage: https://github.com/kristjoc/bible-gateway
;; Package-Requires: ((emacs "29.1"))
;; Package-Version: 0.9

;; This program is free software; you can redistribute it and/or modify
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

;; `bible-gateway` is a simple package that 1) fetches the verse of
;; the day from BibleGateway and formats it to be displayed as the
;; emacs-dashboard footer or *scratch* buffer message, 2) allows users
;; to insert any requested Bible verse or passage at the current point
;; in the buffer, and 3) retrieves any audio chapter from KJV and
;; plays it in a browser tab or using EMMS.
;;
;; Usage:
;;
;; `(bible-gateway-get-verse)' fetches the verse of the day for
;; use as an emacs-dashboard footer or a scratch buffer message.
;;
;; `(bible-gateway-get-passage)' fetches a specific passage and
;; inserts it at point.
;;
;; `(bible-gateway-listen-passage-in-browser)' plays an audio chapter
;; in the browser.
;;
;; `(bible-gateway-listen-passage-with-emms)' plays an audio chapter
;; using EMMS.

;;; Code:

(require 'url)
(require 'json)

(defgroup bible-gateway nil
  "Package that fetches the Bible verse of the day from BibleGateway."
  :group 'external)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                           Customizable variables                           ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defcustom bible-gateway-bible-version "KJV"
  "The Bible version, default KJV.
Other supported versions, which are available in the Public domain, are
LSG in French, RVA in Spanish, ALB in Albanian, and UKR in Ukrainian."
  :type 'string
  :group 'bible-gateway)

(defcustom bible-gateway-text-width 80
  "The width of the verse of the day body in number of characters, default 80."
  :type 'integer
  :group 'bible-gateway)

(defcustom bible-gateway-fallback-verse "For God so loved the world,
that he gave his only begotten Son,
that whosoever believeth in him should not perish,
but have everlasting life."
  "The fallback verse to use when the online request fails."
  :type 'string
  :group 'bible-gateway)

(defcustom bible-gateway-fallback-reference "John 3:16"
  "The reference for the fallback verse."
  :type 'string
  :group 'bible-gateway)

(defcustom bible-gateway-request-timeout 3
  "The timeout for the URL request in seconds."
  :type 'integer
  :group 'bible-gateway)

(defcustom bible-gateway-include-ref t
  "If non-nil, print the reference (e.g., \"John 3 (KJV)\") with the passage."
  :type 'boolean
  :group 'bible-gateway)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                     Bible books in supported languages                     ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defconst bible-gateway-bible-books-kjv
  '(("Genesis" . 50) ("Exodus" . 40) ("Leviticus" . 27) ("Numbers" . 36)
    ("Deuteronomy" . 34) ("Joshua" . 24) ("Judges" . 21) ("Ruth" . 4)
    ("1 Samuel" . 31) ("2 Samuel" . 24) ("1 Kings" . 22) ("2 Kings" . 25)
    ("1 Chronicles" . 29) ("2 Chronicles" . 36) ("Ezra" . 10) ("Nehemiah" . 13)
    ("Esther" . 10) ("Job" . 42) ("Psalms" . 150) ("Proverbs" . 31)
    ("Ecclesiastes" . 12) ("Song of Solomon" . 8) ("Isaiah" . 66) ("Jeremiah" . 52)
    ("Lamentations" . 5) ("Ezekiel" . 48) ("Daniel" . 12) ("Hosea" . 14)
    ("Joel" . 3) ("Amos" . 9) ("Obadiah" . 1) ("Jonah" . 4) ("Micah" . 7)
    ("Nahum" . 3) ("Habakkuk" . 3) ("Zephaniah" . 3) ("Haggai" . 2)
    ("Zechariah" . 14) ("Malachi" . 4) ("Matthew" . 28) ("Mark" . 16)
    ("Luke" . 24) ("John" . 21) ("Acts" . 28) ("Romans" . 16)
    ("1 Corinthians" . 16) ("2 Corinthians" . 13) ("Galatians" . 6)
    ("Ephesians" . 6) ("Philippians" . 4) ("Colossians" . 4)
    ("1 Thessalonians" . 5) ("2 Thessalonians" . 3) ("1 Timothy" . 6)
    ("2 Timothy" . 4) ("Titus" . 3) ("Philemon" . 1) ("Hebrews" . 13)
    ("James" . 5) ("1 Peter" . 5) ("2 Peter" . 3) ("1 John" . 5)
    ("2 John" . 1) ("3 John" . 1) ("Jude" . 1) ("Revelation" . 22))
  "List of Bible books (KJV version) with their number of chapters.")

(defconst bible-gateway-bible-books-lsg
  '(("Genèse" . 50) ("Exode" . 40) ("Lévitique" . 27) ("Nombres" . 36)
    ("Deutéronome" . 34) ("Josué" . 24) ("Juges" . 21) ("Ruth" . 4)
    ("1 Samuel" . 31) ("2 Samuel" . 24) ("1 Rois" . 22) ("2 Rois" . 25)
    ("1 Chroniques" . 29) ("2 Chroniques" . 36) ("Esdras" . 10) ("Néhémie" . 13)
    ("Esther" . 10) ("Job" . 42) ("Psaumes" . 150) ("Proverbes" . 31)
    ("Ecclésiaste" . 12) ("Cantique des Cantiques" . 8) ("Ésaïe" . 66) ("Jérémie" . 52)
    ("Lamentations" . 5) ("Ézéchiel" . 48) ("Daniel" . 12) ("Osée" . 14)
    ("Joël" . 3) ("Amos" . 9) ("Abdias" . 1) ("Jonas" . 4) ("Michée" . 7)
    ("Nahum" . 3) ("Habacuc" . 3) ("Sophonie" . 3) ("Aggée" . 2)
    ("Zacharie" . 14) ("Malachie" . 4) ("Matthieu" . 28) ("Marc" . 16)
    ("Luc" . 24) ("Jean" . 21) ("Actes" . 28) ("Romains" . 16)
    ("1 Corinthiens" . 16) ("2 Corinthiens" . 13) ("Galates" . 6)
    ("Éphésiens" . 6) ("Philippiens" . 4) ("Colossiens" . 4)
    ("1 Thessaloniciens" . 5) ("2 Thessaloniciens" . 3) ("1 Timothée" . 6)
    ("2 Timothée" . 4) ("Tite" . 3) ("Philémon" . 1) ("Hébreux" . 13)
    ("Jacques" . 5) ("1 Pierre" . 5) ("2 Pierre" . 3) ("1 Jean" . 5)
    ("2 Jean" . 1) ("3 Jean" . 1) ("Jude" . 1) ("Apocalypse" . 22))
  "List of Bible books (LSG version) with their number of chapters.")

(defconst bible-gateway-bible-books-rva
  '(("Génesis" . 50) ("Éxodo" . 40) ("Levítico" . 27) ("Números" . 36)
    ("Deuteronomio" . 34) ("Josué" . 24) ("Jueces" . 21) ("Rut" . 4)
    ("1 Samuel" . 31) ("2 Samuel" . 24) ("1 Reyes" . 22) ("2 Reyes" . 25)
    ("1 Crónicas" . 29) ("2 Crónicas" . 36) ("Esdras" . 10) ("Nehemías" . 13)
    ("Ester" . 10) ("Job" . 42) ("Salmos" . 150) ("Proverbios" . 31)
    ("Eclesiastés" . 12) ("Cantares" . 8) ("Isaías" . 66) ("Jeremías" . 52)
    ("Lamentaciones" . 5) ("Ezequiel" . 48) ("Daniel" . 12) ("Oseas" . 14)
    ("Joel" . 3) ("Amós" . 9) ("Abdías" . 1) ("Jonás" . 4) ("Miqueas" . 7)
    ("Nahúm" . 3) ("Habacuc" . 3) ("Sofonías" . 3) ("Hageo" . 2)
    ("Zacarías" . 14) ("Malaquías" . 4) ("Mateo" . 28) ("Marcos" . 16)
    ("Lucas" . 24) ("Juan" . 21) ("Hechos" . 28) ("Romanos" . 16)
    ("1 Corintios" . 16) ("2 Corintios" . 13) ("Gálatas" . 6)
    ("Efesios" . 6) ("Filipenses" . 4) ("Colosenses" . 4)
    ("1 Tesalonicenses" . 5) ("2 Tesalonicenses" . 3) ("1 Timoteo" . 6)
    ("2 Timoteo" . 4) ("Tito" . 3) ("Filemón" . 1) ("Hebreos" . 13)
    ("Santiago" . 5) ("1 Pedro" . 5) ("2 Pedro" . 3) ("1 Juan" . 5)
    ("2 Juan" . 1) ("3 Juan" . 1) ("Judas" . 1) ("Apocalipsis" . 22))
  "List of Bible books (RVA version) with their number of chapters.")

(defconst bible-gateway-bible-books-alb
  '(("Zanafilla" . 50) ("Eksodi" . 40) ("Levitiku" . 27) ("Numrat" . 36)
    ("Ligji i Përtërirë" . 34) ("Jozueu" . 24) ("Gjyqtarët" . 21) ("Ruthi" . 4)
    ("1 i Samuelit" . 31) ("2 i Samuelit" . 24) ("1 i Mbretërve" . 22) ("2 i Mbretërve" . 25)
    ("1 i Kronikave" . 29) ("2 i Kronikave" . 36) ("Esdra" . 10) ("Nehemia" . 13)
    ("Ester" . 10) ("Jobi" . 42) ("Psalmet" . 150) ("Fjalët e urta" . 31)
    ("Predikuesi" . 12) ("Kantiku i Kantikëve" . 8) ("Isaia" . 66) ("Jeremia" . 52)
    ("Vajtimet" . 5) ("Ezekieli" . 48) ("Danieli" . 12) ("Osea" . 14)
    ("Joeli" . 3) ("Amosi" . 9) ("Abdia" . 1) ("Jona" . 4) ("Mikea" . 7)
    ("Nahumi" . 3) ("Habakuku" . 3) ("Sofonia" . 3) ("Hagai" . 2)
    ("Zakaria" . 14) ("Malakia" . 4) ("Mateu" . 28) ("Marku" . 16)
    ("Luka" . 24) ("Gjoni" . 21) ("Veprat e Apostujve" . 28) ("Romakëve" . 16)
    ("1 e Korintasve" . 16) ("2 e Korintasve" . 13) ("Galatasve" . 6)
    ("Efesianëve" . 6) ("Filipianëve" . 4) ("Kolosianëve" . 4)
    ("1 Thesalonikasve" . 5) ("2 Thesalonikasve" . 3) ("1 Timoteut" . 6)
    ("2 Timoteut" . 4) ("Titi" . 3) ("Filemonit" . 1) ("Hebrenjve" . 13)
    ("Jakobit" . 5) ("1 Pjetrit" . 5) ("2 Pjetrit" . 3) ("1 Gjonit" . 5)
    ("2 Gjonit" . 1) ("3 Gjonit" . 1) ("Juda" . 1) ("Zbulesa" . 22))
  "List of Bible books (ALB version) with their number of chapters.")

(defconst bible-gateway-bible-books-ukr
  '(("Буття" . 50) ("Вихід" . 40) ("Левит" . 27) ("Числа" . 36)
    ("Повторення Закону" . 34) ("Ісус Навин" . 24) ("Книга Суддів" . 21) ("Рут" . 4)
    ("1 Самуїлова" . 31) ("2 Самуїлова" . 24) ("1 царів" . 22) ("2 царів" . 25)
    ("1 хроніки" . 29) ("2 хроніки" . 36) ("Ездра" . 10) ("Неемія" . 13)
    ("Естер" . 10) ("Йов" . 42) ("Псалми" . 150) ("Приповісті" . 31)
    ("Екклезіяст" . 12) ("Пісня над піснями" . 8) ("Ісая" . 66) ("Єремія" . 52)
    ("Плач Єремії" . 5) ("Єзекіїль" . 48) ("Даниїл" . 12) ("Осія" . 14)
    ("Йоїл" . 3) ("Амос" . 9) ("Овдій" . 1) ("Йона" . 4) ("Михей" . 7)
    ("Наум" . 3) ("Авакум" . 3) ("Софонія" . 3) ("Огій" . 2)
    ("Захарія" . 14) ("Малахії" . 4) ("Від Матвія" . 28) ("Від Марка" . 16)
    ("Від Луки" . 24) ("Від Івана" . 21) ("Дії" . 28) ("До римлян" . 16)
    ("1 до коринтян" . 16) ("2 до коринтян" . 13) ("До галатів" . 6)
    ("До ефесян" . 6) ("До филип'ян" . 4) ("До колоссян" . 4)
    ("1 до солунян" . 5) ("2 до солунян" . 3) ("1 Тимофію" . 6)
    ("2 Тимофію" . 4) ("До Тита" . 3) ("До Филимона" . 1) ("До євреїв" . 13)
    ("Якова" . 5) ("1 Петра" . 5) ("2 Петра" . 3) ("1 Івана" . 5)
    ("2 Івана" . 1) ("3 Івана" . 1) ("Юда" . 1) ("Об'явлення" . 22))
  "List of Bible books (UKR version) with their number of chapters.")

(defconst bible-gateway-bible-books-cnvs
  '(("创世记" . 50) ("出埃及记" . 40) ("利未记" . 27) ("民数记" . 36)
    ("申命记" . 34) ("约书亚记" . 24) ("士师记" . 21) ("路得记" . 4)
    ("撒母耳记上" . 31) ("撒母耳记下" . 24) ("列王纪上" . 22) ("列王纪下" . 25)
    ("历代志上" . 29) ("历代志下" . 36) ("以斯拉记" . 10) ("尼希米记" . 13)
    ("以斯帖记" . 10) ("约伯记" . 42) ("诗篇" . 150) ("箴言" . 31)
    ("传道书" . 12) ("雅歌" . 8) ("以赛亚书" . 66) ("耶利米书" . 52)
    ("耶利米哀歌" . 5) ("以西结书" . 48) ("但以理书" . 12) ("何西阿书" . 14)
    ("约珥书" . 3) ("阿摩司书" . 9) ("俄巴底亚书" . 1) ("约拿书" . 4) ("弥迦书" . 7)
    ("那鸿书" . 3) ("哈巴谷书" . 3) ("西番雅书" . 3) ("哈该书" . 2)
    ("撒迦利亚书" . 14) ("玛拉基书" . 4) ("Matthew" . 28) ("Mark" . 16)
    ("Luke" . 24) ("John" . 21) ("Acts" . 28) ("Romans" . 16)
    ("1 Corinthians" . 16) ("2 Corinthians" . 13) ("Galatians" . 6)
    ("Ephesians" . 6) ("Philippians" . 4) ("Colossians" . 4)
    ("1 Thessalonians" . 5) ("2 Thessalonians" . 3) ("1 Timothy" . 6)
    ("2 Timothy" . 4) ("Titus" . 3) ("Philemon" . 1) ("Hebrews" . 13)
    ("James" . 5) ("1 Peter" . 5) ("2 Peter" . 3) ("1 John" . 5)
    ("2 John" . 1) ("3 John" . 1) ("Jude" . 1) ("Revelation" . 22))
  "List of Bible books (CNVS version) with their number of chapters.")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                     Package Section I: Fetch the Verse of The Day          ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun bible-gateway-justify-line (line width)
  "Justify LINE to WIDTH characters."
  (let* ((words (split-string line))
         (word-count (length words)))
    (if (<= word-count 1)
        line  ; Return single words unchanged
      (let* ((total-word-length (apply #'+ (mapcar #'length words)))
             (spaces-needed (- width total-word-length))
             (gaps (1- word-count))
             (base-spaces-per-gap (/ spaces-needed gaps))
             (extra-spaces (% spaces-needed gaps))
             (result ""))
        ;; Distribute spaces as evenly as possible
        (dotimes (i (1- word-count))
          (setq result
                (concat result
                        (nth i words)
                        (make-string
                         (if (< i extra-spaces)
                             (1+ base-spaces-per-gap)
                           base-spaces-per-gap)
                         ?\s))))
        (concat result (car (last words)))))))

(defun bible-gateway-format-verse-text (text &optional width)
  "Format verse TEXT as a justified paragraph with optional WIDTH."
  (when text  ; Only process if text is not nil
    (with-temp-buffer
      (let* ((fill-column (or width bible-gateway-text-width))
             (lines '()))
        ;; First fill the paragraph normally
        (insert text)
        (fill-region (point-min) (point-max))
        ;; Collect lines
        (goto-char (point-min))
        (while (not (eobp))
          (let ((line (string-trim (buffer-substring (line-beginning-position)
                                                     (line-end-position)))))
            (unless (string-empty-p line)
              (push line lines)))
          (forward-line 1))
        ;; Justify each line except the last one
        (setq lines (nreverse lines))
        (let* ((justified-lines
                (append
                 (mapcar (lambda (line)
                           (bible-gateway-justify-line line fill-column))
                         (butlast lines))
                 (last lines)))
               (result (string-join justified-lines "\n")))
          result)))))

(defun bible-gateway-decode-html-entities (text)
  "Decode HTML entities in TEXT, including numeric character references."
  (when text
    (let ((entity-map '(("&ldquo;" . "\"")
  ("&rdquo;" . "\"")
  ("&#8212;" . "--")
  ("&#8217;" . "'")
  ("&#8220;" . "\"")
  ("&#8221;" . "\"")
  ("&quot;" . "\"")
  ("&apos;" . "'")
  ("&lt;" . "<")
  ("&gt;" . ">")
  ("&nbsp;" . " ")
  ("&amp;" . "&") ; Decode &amp; first
  ("&#039;" . "'")))) ; Decode numeric entities like &#039; after &amp;
      ;; Replace named entities
      (dolist (entity entity-map text)
        (setq text (replace-regexp-in-string (car entity) (cdr entity) text)))
      ;; Replace numeric character references (e.g., &#233; -> é)
      ;; Fix for special characters in LSG and RVA
      (setq text
	    (replace-regexp-in-string "&#\\([0-9]+\\);"
                                      (lambda (match)
                                        (char-to-string (string-to-number (match-string 1 match))))
                                      text))
      ;; Return the decoded text
      text)))

(defun bible-gateway-fetch-daily-bible-verse ()
  "Fetch the daily Bible verse from BibleGateway API."
  (let ((url-request-method "GET")
        (url (concat "https://www.biblegateway.com/votd/get/?format=json&version=" bible-gateway-bible-version)))
    (condition-case nil
        (with-current-buffer (url-retrieve-synchronously url t t bible-gateway-request-timeout)
          (goto-char (point-min))
          (when (search-forward "\n\n" nil t)
            (let* ((json-string (buffer-substring-no-properties (point) (point-max)))
                   (json-object-type 'hash-table)
                   (json-array-type 'list)
                   (json-key-type 'string)
                   (json-data (json-read-from-string json-string))
                   (votd (gethash "votd" json-data))
                   (raw-text (gethash "text" votd))
                   (verse-text (bible-gateway-decode-html-entities raw-text))
                   (clean-verse (replace-regexp-in-string "[\"]" "" verse-text))
                   (formatted-verse (bible-gateway-format-verse-text clean-verse))
                   (verse-reference (gethash "display_ref" votd))
                   (fill-width bible-gateway-text-width))
              (format "%s\n%s"
                      formatted-verse
                      (let ((ref-text verse-reference))
                        (concat (make-string (- fill-width (length ref-text)) ?\s)
                                ref-text))))))
      (error
       (message "%s\n%s"
                (bible-gateway-format-verse-text bible-gateway-fallback-verse)
                (let ((ref-text bible-gateway-fallback-reference))
                  (concat (make-string (- bible-gateway-text-width (length ref-text)) ?\s)
                          ref-text)))))))

;;;###autoload
(defun bible-gateway-get-verse ()
  "Get the daily verse and handle errors."
  (condition-case err
      (bible-gateway-fetch-daily-bible-verse)
    (error
     (message "Today's verse could not be fetched: %s" (error-message-string err)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                     Package section II - Fetch a Bible Passage             ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun bible-gateway-read-book ()
  "Read a Bible book name with completion based on selected Bible version."
  (completing-read
   "Select a Book: "
   (mapcar #'car  ; Get just the book names for completion
           (cond ((string= bible-gateway-bible-version "KJV")
                  bible-gateway-bible-books-kjv)
                 ((string= bible-gateway-bible-version "LSG")
                  bible-gateway-bible-books-lsg)
                 ((string= bible-gateway-bible-version "RVA")
                  bible-gateway-bible-books-rva)
                 ((string= bible-gateway-bible-version "ALB")
                  bible-gateway-bible-books-alb)
                 ((string= bible-gateway-bible-version "UKR")
                  bible-gateway-bible-books-ukr)
                 ((string= bible-gateway-bible-version "CNVS")
                  bible-gateway-bible-books-cnvs)
                 (t bible-gateway-bible-books-kjv)))
   nil t))

(defun bible-gateway-get-chapter-count (book version)
  "Get the number of chapters for BOOK in the given VERSION."
  (let ((books-list (cond ((string= version "KJV")
                           bible-gateway-bible-books-kjv)
                          ((string= version "LSG")
                           bible-gateway-bible-books-lsg)
                          ((string= version "RVA")
                           bible-gateway-bible-books-rva)
			  ((string= version "ALB")
                           bible-gateway-bible-books-alb)
                          ((string= version "UKR")
                           bible-gateway-bible-books-ukr)
                          ((string= version "CNVS")
                           bible-gateway-bible-books-cnvs)
                          (t bible-gateway-bible-books-kjv))))
    (cdr (assoc book books-list))))

(defun bible-gateway-read-chapter-verse (book)
  "Read chapter and verse for BOOK."
  (let* ((books-list (cond ((string= bible-gateway-bible-version "KJV")
                            bible-gateway-bible-books-kjv)
                           ((string= bible-gateway-bible-version "LSG")
                            bible-gateway-bible-books-lsg)
                           ((string= bible-gateway-bible-version "RVA")
                            bible-gateway-bible-books-rva)
                           ((string= bible-gateway-bible-version "ALB")
                            bible-gateway-bible-books-alb)
                           ((string= bible-gateway-bible-version "UKR")
                            bible-gateway-bible-books-ukr)
                           ((string= bible-gateway-bible-version "CNVS")
                            bible-gateway-bible-books-cnvs)
                           (t bible-gateway-bible-books-kjv)))
         (max-chapters (cdr (assoc book books-list))))
    (unless max-chapters
      (error "Could not find chapter count for book: %s in version %s" book bible-gateway-bible-version))
    (let ((input (read-string
                  (format "Select passage from %s (1-%d): " book max-chapters))))
      (format "%s %s" book input))))

(defun bible-gateway-process-verse-text (text)
  "Process verse TEXT.
Handling special cases like small-caps LORD and UTF-8 encoding."
  (let ((processed-text text))
    ;; First decode UTF-8 octal sequences
    (setq processed-text
          (decode-coding-string
           (encode-coding-string processed-text 'utf-8)
	   'utf-8))

    ;; Replace small-caps span with "LORD"
    (setq processed-text
          (replace-regexp-in-string
           "<span style=\"font-variant: small-caps\" class=\"small-caps\">\\(Lord\\)</span>"
           "LORD"
           processed-text t))

    ;; Remove "Read full chapter" text
    (setq processed-text
          (replace-regexp-in-string "Read full chapter.*$" "" processed-text))

    ;; Remove trailing span IDs and div tags
    (setq processed-text
          (replace-regexp-in-string "\\(<span id=\"[^\"]*\".*\\|</div.*\\)$" "" processed-text))

    ;; Remove any remaining HTML tags
    (setq processed-text
          (replace-regexp-in-string "<[^>]+>" "" processed-text))

    ;; Fix non-breaking space
    (setq processed-text
          (replace-regexp-in-string "\\\\302\\\\240" " " processed-text))

    ;; Decode HTML entities (if any remain)
    (setq processed-text (bible-gateway-decode-html-entities processed-text))

    ;; Trim whitespace and return
    (string-trim processed-text)))

(defun bible-gateway-wrap-verse-text (verse-text)
  "Wrap VERSE-TEXT according to window width with 4 spaces for wrapped lines."
  (with-temp-buffer
    (insert verse-text)
    (let ((fill-prefix "    ")  ; 4 spaces for wrapped lines
          (fill-column (- (window-width) 5))) ; window width minus some margin
      (fill-region (point-min) (point-max))
      (buffer-string))))

;;;###autoload
(defun bible-gateway-get-passage ()
  "Fetch a Bible passage from https://biblegateway.com/."
  (interactive)
  (let* ((book (bible-gateway-read-book))
         (passage (bible-gateway-read-chapter-verse book))
	 (formatted-passage (replace-regexp-in-string " " "" passage))
         (url (concat "https://www.biblegateway.com/passage/?search="
		      formatted-passage "&version=" bible-gateway-bible-version)))
    (condition-case err
        (let ((original-buffer (current-buffer)))
          (with-current-buffer (url-retrieve-synchronously url t t bible-gateway-request-timeout)
            (goto-char (point-min))

	    ;; First get the title if required
	    (let ((title nil))
	      (when bible-gateway-include-ref
		(goto-char (point-min))
		(when (search-forward "<meta name=\"twitter:title\" content=\"" nil t)
		  (let ((start (point))
			(end (search-forward "\"")))
		    ;; Decode the title here
		    (setq title (decode-coding-string
				 (encode-coding-string
				  (buffer-substring-no-properties start (1- end)) 'utf-8)
				 'utf-8)))))

              ;; Then get the verses
              (goto-char (point-min))
              (if (search-forward "<div class='passage-content passage-class-0'>" nil t)
                  (let* ((start (point))
                         (end (search-forward "</div>"))
                         (raw-content (buffer-substring-no-properties start (1- end)))
                         (verses '()))
                    ;; (pos 0))

                ;; First, remove chapter numbers
                (setq raw-content
                      (replace-regexp-in-string
		       "<span class=\"chapternum\">[^<]*</span>" "" raw-content))

                ;; Remove verse numbers but keep content
                (setq raw-content
                      (replace-regexp-in-string
		       "<sup class=\"versenum\">[^<]*</sup>" "" raw-content))

                ;; Break the content into individual verse spans for processing
                (with-temp-buffer
                  (insert raw-content)
                  (goto-char (point-min))
                  (while (re-search-forward "class=\"text [^\"]*-\\([0-9]+\\)\">" nil t)
                    (let* ((verse-num (match-string 1))
                           (verse-start (match-end 0))
                           (verse-end (save-excursion
                                        (if (re-search-forward "class=\"text" nil t)
					    (match-beginning 0)
                                          (point-max))))
                           (verse-content
			    (buffer-substring-no-properties verse-start verse-end))
			   ;; First process the verse text normally
                           (verse-text (bible-gateway-process-verse-text verse-content))
			   ;; Then wrap it with proper formatting
			   (final-text (bible-gateway-wrap-verse-text verse-text)))
                      (when (not (string-empty-p final-text))
			(push (format "%s.%s%s" verse-num
				      (if (< (string-to-number verse-num) 10) "  " " ")
				      final-text)
			      verses)))))

                ;; Insert title and verses
                (with-current-buffer original-buffer
                  (when (and bible-gateway-include-ref title)
		    (insert title "\n\n"))
                  (insert (string-join (reverse verses) "\n"))))
	      (message "Sorry, we didn’t find any results for your search. Please double-check that the chapter and verse numbers are valid.")))))
    ('error
     (message "Error while fetching the passage: %s" (error-message-string err))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                    Package Section III - Play Audio chapter                ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defconst bible-gateway-bible-books-osis
  '(("Genesis" . "Gen") ("Exodus" . "Exod") ("Leviticus" . "Lev")
    ("Numbers" . "Num") ("Deuteronomy" . "Deut") ("Joshua" . "Josh")
    ("Judges" . "Judg") ("Ruth" . "Ruth") ("1 Samuel" . "1Sam")
    ("2 Samuel" . "2Sam") ("1 Kings" . "1Kgs") ("2 Kings" . "2Kgs")
    ("1 Chronicles" . "1Chr") ("2 Chronicles" . "2Chr") ("Ezra" . "Ezra")
    ("Nehemiah" . "Neh") ("Esther" . "Esth") ("Job" . "Job")
    ("Psalms" . "Ps") ("Proverbs" . "Prov") ("Ecclesiastes" . "Eccl")
    ("Song of Solomon" . "Song") ("Isaiah" . "Isa") ("Jeremiah" . "Jer")
    ("Lamentations" . "Lam") ("Ezekiel" . "Ezek") ("Daniel" . "Dan")
    ("Hosea" . "Hos") ("Joel" . "Joel") ("Amos" . "Amos")
    ("Obadiah" . "Obad") ("Jonah" . "Jonah") ("Micah" . "Mic")
    ("Nahum" . "Nah") ("Habakkuk" . "Hab") ("Zephaniah" . "Zeph")
    ("Haggai" . "Hag") ("Zechariah" . "Zech") ("Malachi" . "Mal")
    ("Matthew" . "Matt") ("Mark" . "Mark") ("Luke" . "Luke")
    ("John" . "John") ("Acts" . "Acts") ("Romans" . "Rom")
    ("1 Corinthians" . "1Cor") ("2 Corinthians" . "2Cor")
    ("Galatians" . "Gal") ("Ephesians" . "Eph") ("Philippians" . "Phil")
    ("Colossians" . "Col") ("1 Thessalonians" . "1Thess")
    ("2 Thessalonians" . "2Thess") ("1 Timothy" . "1Tim")
    ("2 Timothy" . "2Tim") ("Titus" . "Titus") ("Philemon" . "Phlm")
    ("Hebrews" . "Heb") ("James" . "Jas") ("1 Peter" . "1Pet")
    ("2 Peter" . "2Pet") ("1 John" . "1John") ("2 John" . "2John")
    ("3 John" . "3John") ("Jude" . "Jude") ("Revelation" . "Rev"))
  "Mapping of Bible book names to their OSIS abbreviations for audio links.")

(defun bible-gateway-get-audio-link (book chapter)
  "Generate and open BibleGateway audio link for BOOK CHAPTER and optional VERSE."
  (let* ((osis-code (cdr (assoc book bible-gateway-bible-books-osis)))
         (version (downcase bible-gateway-bible-version))
         (base-url "https://www.biblegateway.com/audio/dramatized")
         (url (if osis-code
                  (format "%s/%s/%s.%d" base-url version osis-code chapter)
		(error "Unknown book: %s" book))))
    ;; Open URL in browser
    (browse-url url)
    ;; Return URL for display
    url))

;;;###autoload
(defun bible-gateway-listen-passage-in-browser ()
  "Open a browser tab to listen the requested chapter."
  (interactive)
  (let* ((books-list (cond ((string= bible-gateway-bible-version "KJV")
                            bible-gateway-bible-books-kjv)
                           (t bible-gateway-bible-books-kjv)))
         (book (completing-read "Select Book: " (mapcar #'car books-list)))
         (max-chapters (cdr (assoc book books-list)))
         (input (read-string
                 (format "Select Chapter from %s (1-%d): " book max-chapters)))
         (audio-link (bible-gateway-get-audio-link book (string-to-number input))))
    ;; More detailed message with the specific chapter being opened
    (message "Switch to your browser and click Play to listen %s %s (KJV)."
             book input)))

;;;###autoload
(defun bible-gateway-listen-passage-with-emms ()
  "Download and play the requested Bible chapter audio with EMMS."
  (interactive)
  (let* ((books-list (cond ((string= bible-gateway-bible-version "KJV")
                            bible-gateway-bible-books-kjv)
                           (t bible-gateway-bible-books-kjv)))
         (book (completing-read "Select Book: " (mapcar #'car books-list)))
         (max-chapters (cdr (assoc book books-list)))
         (input (read-string
                 (format "Select Chapter from %s (1-%d): " book max-chapters)))
         ;; Get the audio link but don't open it in a browser
         (audio-link (let ((browse-url-browser-function #'ignore)
                           (url-show-status nil)) ; Silence "Contacting host..." messages
                       (bible-gateway-get-audio-link book (string-to-number input))))
	 (output-file (expand-file-name (concat book "-" input ".mp3")
					(temporary-file-directory)))
         (temp-html-file (expand-file-name "bible-page.html"
					   (temporary-file-directory))))

    ;; Check if the file already exists in /tmp
    (if (file-exists-p output-file)
	;; If it exists, play it directly
	(progn
          (message "Playing %s %s..." book input)
          (if (fboundp 'emms-play-file)
              (emms-play-file output-file)
            (start-process "mplayer" nil "mplayer" output-file)))

      ;; If it doesn't exist, download it
      ;; Download the page first
      (call-process-shell-command
       (format "curl -s '%s' > %s" audio-link temp-html-file))

      ;; Use grep to extract the MP3 URL
      (let* ((mp3-url (string-trim (shell-command-to-string
                                    (format "grep -o 'https://streamnew.biblegateway.com/bibles/[^\"]*\\.mp3' %s | head -1"
                                            temp-html-file)))))

	;; Remove the temporary HTML file
	(when (file-exists-p temp-html-file)
          (delete-file temp-html-file))

	(if (string-match "^https://" mp3-url)
            (progn
              ;; Download the MP3 file using url-copy-file with status messages suppressed
              (let ((url-show-status nil))
		(url-copy-file mp3-url output-file t))

              ;; Play the file if it exists
              (if (file-exists-p output-file)
                  (progn
                    (message "Playing %s %s..." book input)
                    (if (fboundp 'emms-play-file)
			(progn
			  (require 'emms)
			  ;; (let ((emms-player-list-1 emms-player-list))
                          (emms-play-file output-file))
                      (start-process "mplayer" nil "mplayer" output-file)))
		(progn
		  (message "Failed to download audio for %s %s" book input))
		(message "No audio found for %s %s" book input))))))))

(provide 'bible-gateway)
;;; bible-gateway.el ends here
