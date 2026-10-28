;; skeleton.nvim - fill new files from skeleton templates, expanded by LuaSnip.
;; Choosing the skeleton is skeleton.match; this module wires it to buffers:
;; the BufNewFile hook, the picker, expansion, and the user commands.

(local matcher (require :skeleton.match))

(local state {:dirs [] :pending nil}) ; pending: selection waiting for the next new file

(fn escape-lsp [s]
  ;; Why: a value pasted into template text must not be read as snippet
  ;; syntax (a file called $x or a } in a name).
  (pick-values 1 (: (s:gsub "[\\$}]" "\\%0") :gsub "%%" "%%%%")))

(fn with-name [text filename]
  ;; Why: $NAME - the new file's name up to its first dot (Button.stories.js
  ;; -> Button), used for component names and imports. Substituted as text
  ;; because LuaSnip only knows its own variables.
  (let [name (escape-lsp (or (filename:match "^([^.]+)") filename))]
    (pick-values 1 (-> text
                       (: :gsub "%${NAME}" name)
                       (: :gsub "%$NAME%f[^%w_]" name)))))

(fn take-selection [buf]
  ;; Why: LuaSnip's cut keys (select, then cut) store the selection on the
  ;; buffer it was cut from, but the skeleton expands in the new file's
  ;; buffer. Take it from there (once) so it fills $TM_SELECTED_TEXT.
  (when (and buf (vim.api.nvim_buf_is_valid buf))
    (let [(ok raw) (pcall vim.api.nvim_buf_get_var buf "LUASNIP_SELECT_RAW")]
      (when ok
        (let [sel {:LS_SELECT_RAW raw
                   :LS_SELECT_DEDENT (vim.api.nvim_buf_get_var buf "LUASNIP_SELECT_DEDENT")
                   :TM_SELECTED_TEXT (vim.api.nvim_buf_get_var buf "LUASNIP_TM_SELECT")}]
          (each [_ v (ipairs ["LUASNIP_SELECT_RAW" "LUASNIP_SELECT_DEDENT" "LUASNIP_TM_SELECT"])]
            (vim.api.nvim_buf_del_var buf v))
          sel)))))

(fn expand [buf path]
  ;; Why: the skeleton becomes a LuaSnip snippet expanded at the top of the
  ;; empty buffer, so <C-j>/<C-k> walk its tab stops like any snippet.
  (let [ls (require :luasnip)
        text (with-name (table.concat (vim.fn.readfile path) "\n")
                        (vim.fs.basename (vim.api.nvim_buf_get_name buf)))
        snip (ls.parser.parse_snippet "" text {:trim_empty false :dedent false})
        selection (or state.pending {})]
    (set state.pending nil)
    (vim.api.nvim_set_current_buf buf)
    (vim.api.nvim_win_set_cursor 0 [1 0])
    (ls.snip_expand snip {:pos [0 0] :expand_params {:env_override selection}})))

(fn label [s]
  ;; Why: what the picker shows for a skeleton.
  (if s.type (.. s.type "." s.ext) (.. s.ext " (default)")))

(fn pick [choices default on-choice]
  ;; Why: several skeletons fit - ask, default first, with an "empty file"
  ;; way out. Telescope (with a preview) if present, else vim.ui.select.
  (let [items (icollect [_ s (ipairs choices)] (when (= s.path default) s))]
    (each [_ s (ipairs choices)]
      (when (not= s.path default) (table.insert items s)))
    (table.insert items {:empty true})
    (let [(has-telescope) (pcall require :telescope)]
      (if has-telescope
        (let [pickers (require :telescope.pickers)
              finders (require :telescope.finders)
              previewers (require :telescope.previewers)
              actions (require :telescope.actions)
              action-state (require :telescope.actions.state)
              conf (. (require :telescope.config) :values)]
          (: (pickers.new {}
               {:prompt_title "Skeleton"
                :finder (finders.new_table
                          {:results items
                           :entry_maker (fn [s]
                                          (let [text (if s.empty "empty file" (label s))]
                                            {:value s :display text :ordinal text}))})
                :sorter (conf.generic_sorter {})
                :previewer (previewers.new_buffer_previewer
                             {:define_preview
                              (fn [self entry]
                                (vim.api.nvim_buf_set_lines
                                  self.state.bufnr 0 -1 false
                                  (if entry.value.empty [] (vim.fn.readfile entry.value.path))))})
                :attach_mappings
                (fn [bufnr]
                  (actions.select_default:replace
                    (fn []
                      (let [entry (action-state.get_selected_entry)]
                        (actions.close bufnr)
                        (when (and entry (not entry.value.empty))
                          (on-choice entry.value.path)))))
                  true)})
             :find))
        (vim.ui.select items
                       {:prompt "Skeleton"
                        :format_item #(if $1.empty "empty file" (label $1))}
                       (fn [s] (when (and s (not s.empty)) (on-choice s.path))))))))

(fn empty-buffer? [buf]
  (and (vim.api.nvim_buf_is_valid buf)
       (= (vim.api.nvim_buf_line_count buf) 1)
       (= "" (. (vim.api.nvim_buf_get_lines buf 0 1 false) 1))))

(fn apply [?buf]
  ;; Why: the core action - choose a skeleton for this (empty) buffer's file
  ;; name and expand it. Returns nothing; does nothing when none fits.
  (let [buf (if (or (= nil ?buf) (= 0 ?buf)) (vim.api.nvim_get_current_buf) ?buf)
        filename (vim.fs.basename (vim.api.nvim_buf_get_name buf))
        choice (and (not= filename "") (matcher.choose filename (matcher.scan state.dirs)))]
    (when (and choice (empty-buffer? buf))
      (if choice.auto
        (expand buf choice.auto)
        (pick choice.pick choice.default #(when (empty-buffer? buf) (expand buf $1)))))))

(fn new-skeleton [?spec]
  ;; Why: making a skeleton is just creating skeleton.<type>.<ext> in the
  ;; first skeleton directory; it is usable as soon as it is saved.
  (let [open #(when (and $1 (not= $1 ""))
                (vim.cmd.edit (vim.fn.fnameescape
                                (.. (vim.fs.normalize (. state.dirs 1)) "/skeleton." $1))))]
    (if (and ?spec (not= ?spec ""))
      (open ?spec)
      (vim.ui.input {:prompt "New skeleton: skeleton."} open))))

(fn cut-then-new [?dir ?prompt ?ext]
  ;; Why: "move this code into a new file" in one key (visual mode): cut the
  ;; selection, ask for a file name, and let the skeleton put the code at its
  ;; $TM_SELECTED_TEXT. Replaces UltiSnips#SaveLastVisualSelection() +
  ;; template#MakeNewFile() in project .nvimrc maps.
  (let [lines (vim.fn.getregion (vim.fn.getpos "v") (vim.fn.getpos ".") {:type (vim.fn.mode)})
        dir (or ?dir (vim.fn.expand "%:p:h"))]
    (vim.cmd "normal! \"_d")
    (set state.pending {:LS_SELECT_RAW lines :LS_SELECT_DEDENT lines :TM_SELECTED_TEXT lines})
    (vim.ui.input {:prompt (or ?prompt "New file name: ") :completion "file"}
                  (fn [name]
                    (if (and name (not= (vim.trim name) ""))
                      (vim.cmd.edit (vim.fn.fnameescape (.. dir "/" (vim.trim name) (or ?ext ""))))
                      (set state.pending nil))))))

(fn setup [?opts]
  ;; Why: tell the plugin where skeletons live, and fill every new file.
  (set state.dirs (or (and ?opts ?opts.dirs) ["~/.config/nvim/skeletons"]))
  (vim.api.nvim_create_autocmd "BufNewFile"
    {:group (vim.api.nvim_create_augroup "skeleton.nvim" {:clear true})
     :callback (fn [args]
                 (when (= "" (. vim.bo args.buf :buftype))
                   (let [from (vim.fn.bufnr "#")]
                     ;; Deferred: events right after BufNewFile (BufEnter,
                     ;; filetype detection) would end a snippet started now.
                     (vim.schedule
                       (fn []
                         (when (= args.buf (vim.api.nvim_get_current_buf))
                           (set state.pending (or state.pending (take-selection from)))
                           (apply args.buf)))))))})
  (vim.api.nvim_create_user_command "SkeletonApply" #(apply 0) {:desc "Fill this empty buffer from a skeleton"})
  (vim.api.nvim_create_user_command "SkeletonNew" #(new-skeleton $1.args)
                                    {:nargs "?" :desc "Create skeleton.<type>.<ext>"}))

{: setup : apply :new_skeleton new-skeleton :cut_then_new cut-then-new :_with_name with-name}
