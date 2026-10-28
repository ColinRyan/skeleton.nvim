;; Which skeleton fits a new file. Pure functions (no buffers), so the rules
;; are testable headlessly: see test/match_spec.lua.
;;
;; Skeleton files are named skeleton.<type>.<ext> (type may contain dots) or
;; skeleton.<ext> (the extension's default).

(fn parse-skeleton [path]
  ;; Why: the skeleton's name carries its type and extension.
  ;; skeleton.react.functional.js -> {:type "react.functional" :ext "js"}
  (let [rest (: (vim.fs.basename path) :match "^skeleton%.(.+)$")]
    (when rest
      (let [(type* ext) (rest:match "^(.+)%.([^.]+)$")]
        (if ext
          {: path :type type* : ext}
          {: path :ext rest})))))

(fn scan [dirs]
  ;; Why: rescanned on every use, so a skeleton saved a moment ago is
  ;; already available (the directories are small).
  (let [out []]
    (each [_ dir (ipairs dirs)]
      (each [name kind (vim.fs.dir (vim.fs.normalize dir))]
        (when (= kind "file")
          (let [s (parse-skeleton (.. (vim.fs.normalize dir) "/" name))]
            (when s (table.insert out s))))))
    (table.sort out #(< $1.path $2.path))
    out))

(fn file-parts [filename]
  ;; Why: a new file's extension, and whether its name has a type part
  ;; (Button.stories.js has one, Button.js and .eslintrc don't).
  (let [name (or (filename:match "^%.(.+)$") filename)
        ext (name:match "%.([^.]+)$")]
    (if (filename:match "^%.[^.]+$")
      {:ext name :typed false}
      ext
      {: ext :typed (not= nil (: (name:sub 1 (- (length name) (length ext) 1)) :find "." 1 true))}
      nil)))

(fn choose [filename skeletons]
  ;; Why: Colin's rule - a name that says the type gets that skeleton; a plain
  ;; name with one candidate gets it; anything else asks (default first).
  ;; Returns {:auto path}, {:pick [skeleton...] :default path|nil}, or nil.
  (let [parts (file-parts filename)
        candidates (if parts
                     (icollect [_ s (ipairs skeletons)] (when (= s.ext parts.ext) s))
                     [])]
    (when (> (length candidates) 0)
      (var named nil)
      (each [_ s (ipairs candidates)]
        (when (and s.type
                   (vim.endswith filename (.. "." s.type "." s.ext))
                   (or (not named) (> (length s.type) (length named.type))))
          (set named s)))
      (if named
        {:auto named.path}
        (and (not parts.typed) (= 1 (length candidates)))
        {:auto (. candidates 1 :path)}
        {:pick candidates
         :default (accumulate [d nil _ s (ipairs candidates)] (or d (when (= nil s.type) s.path)))}))))

{: scan : choose : parse-skeleton}
