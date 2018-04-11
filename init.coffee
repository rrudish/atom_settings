editor = atom.workspace.getActiveTextEditor()


split_first_last = (str, first, last) ->
    num_spaces = " ".repeat(str.search(/\S/))
    no_white = str.replace(/^\s+|\s+$/g, "")
    first_idx = no_white.indexOf(first)
    last_idx = no_white.lastIndexOf(last)
    line1 = num_spaces + no_white.slice(0, first_idx + 1)
    line2 = num_spaces + editor.getTabText() + no_white.substring(first_idx + 1, last_idx)
    line3 = num_spaces + no_white.slice(last_idx)
    return [line1, line2, line3]


split_all = (str, char) ->
    splits = []
    num_spaces = " ".repeat(str.search(/\S/))
    no_white = str.replace(/^\s+|\s+$/g, "")
    split_line = no_white.split(char)
    for sp, i in split_line
        new_line = num_spaces + sp.replace(/^\s+|\s+$/g, "")
        if i != split_line.length - 1
            new_line += char
        splits.push(new_line)
    return splits


get_long_lines_in_selection = (len) ->
    editor = atom.workspace.getActiveTextEditor()
    cp = editor.createCheckpoint()
    selected_ranges = editor.getSelectedBufferRanges()
    long_lines = new Set()
    for range in selected_ranges
        rows = [range["start"]["row"]..range["end"]["row"]]
        for row in rows
            text = editor.lineTextForScreenRow(row)
            if text.length > len
                long_lines.add(row)
    long_lines = Array.from(long_lines)
    long_lines.sort()
    return long_lines


atom.commands.add 'atom-text-editor', 'custom:split-line-by-closures', ->
    editor = atom.workspace.getActiveTextEditor()
    cp = editor.createCheckpoint()
    long_lines = get_long_lines_in_selection(79)
    for row in long_lines
        row_text = editor.lineTextForScreenRow(row)
        o_paren_idx = row_text.indexOf("(")
        c_paren_idx = row_text.indexOf(")")
        complete_parens = o_paren_idx != -1 and c_paren_idx != -1 and o_paren_idx != c_paren_idx - 1
        o_brkt_idx = row_text.indexOf("[")
        c_brkt_idx = row_text.indexOf("]")
        complete_brkts = o_brkt_idx != -1 and c_brkt_idx != -1 and o_brkt_idx != c_brkt_idx - 1
        o_brace_idx = row_text.indexOf("{")
        c_brace_idx = row_text.indexOf("}")
        complete_braces = o_brace_idx != -1 and c_brace_idx != -1 and o_brace_idx != c_brace_idx - 1
        indecies = [o_paren_idx, o_brkt_idx, o_brace_idx]
        indecies.sort()
        indecies = indecies.filter (x) -> x != -1
        console.log indecies
        console.log complete_parens
        console.log complete_brkts
        console.log complete_braces
        console.log indecies
        if indecies == []
            continue
        if complete_parens and o_paren_idx == indecies[0]
            first = ["(", ")"]
        else if complete_brkts and o_brkt_idx == indecies[0]
            first = ["[", "]"]
        else if complete_braces and o_brace_idx == indecies[0]
            first = ["{", "}"]
        console.log 'first', first
        new_lines = split_first_last(row_text, first[0], first[1])
        editor.setTextInBufferRange([[row, 0], [row, row_text.length]], new_lines.join("\n"))
        for _, n in long_lines
            long_lines[n] += 2
        cursor_pos = editor.getCursorScreenPositions()
        if not editor.hasMultipleCursors()
            cursor = editor.getLastCursor()
            cursor.moveUp()
            cursor.moveToEndOfLine()
    editor.groupChangesSinceCheckpoint(cp)


atom.commands.add 'atom-text-editor', 'custom:split-line-by-commas', ->
    editor = atom.workspace.getActiveTextEditor()
    cp = editor.createCheckpoint()
    long_lines = get_long_lines_in_selection(79)
    for row in long_lines
        row_text = editor.lineTextForScreenRow(row)
        comma_idx = row_text.indexOf(",")
        if comma_idx != -1
            new_lines = split_all(row_text, ",")
        else
            continue
        editor.setTextInBufferRange(
            [[row, 0], [row, row_text.length]], new_lines.join("\n")
        )
        for _, n in long_lines
            long_lines[n] += new_lines.length - 1
    editor.groupChangesSinceCheckpoint(cp)


atom.commands.add 'atom-text-editor', 'custom:tab-new-line-or-indent', ->
    editor = atom.workspace.getActiveTextEditor()
    pos = editor.getCursorScreenPosition()
    text = editor.lineTextForScreenRow(pos["row"])
    text = text.replace /^\s+|\s+$/g, ""
    if text == ""
        editor.insertText("    ")
    else
        atom.commands.dispatch(
            atom.views.getView(editor), 'editor:indent-selected-rows'
        )


atom.commands.add 'atom-text-editor', 'custom:test-sniper', ->
  editor = atom.workspace.getActiveTextEditor()
  open_file_path = editor.getPath()
  if open_file_path
    project_folders = atom.project.getPaths()
    for project in project_folders
      open_file_path = open_file_path.replace project, "."
    open_file_path = open_file_path.replace /\\/g, "/"
    open_file_path = "tox -- " + open_file_path
    selection = editor.getLastSelection()
    selected_text = selection.getText()
    if selected_text.toLowerCase().startsWith("test")
      pos = editor.getCursorScreenPosition()
      next_five_chars = editor.getTextInBufferRange([
          pos,
          [pos["row"], pos["column"] + 5]
      ])
      is_method = next_five_chars == "(self" or next_five_chars == "(cls,"
      class_name = ""
      if is_method
        current_row = pos["row"]
        while class_name == "" and current_row > 0
          possible_class_text = editor.getTextInBufferRange([
              [current_row, 0],
              [current_row, 10],
          ])
          if possible_class_text == "class Test"
              current_column = 6
              class_buffer = ""
              while not class_buffer.endsWith("(") and current_column < 1000
                class_buffer = class_buffer + editor.getTextInBufferRange([
                    [current_row, current_column],
                    [current_row, current_column + 1],
                ])
                current_column += 1
              class_name = class_buffer.slice(0, -1)
          current_row -= 1
      if class_name != ""
        open_file_path = open_file_path + "::" + class_name + "::" + selected_text
      else
        open_file_path = open_file_path + "::" + selected_text
    atom.clipboard.write(open_file_path)
    atom.notifications.addInfo("Sniped:  " + open_file_path)
  else
    atom.notifications.addWarning("Couldn't snipe test, file not saved?")


atom.commands.add 'atom-text-editor', 'custom:import-sniper', ->
  editor = atom.workspace.getActiveTextEditor()
  open_file_path = editor.getPath()
  import_text = ""
  if open_file_path
    for project in atom.project.getPaths()
      if open_file_path.startsWith(project + "\\")
        import_text = open_file_path.replace project + "\\", ""
        import_text = import_text.replace /\\/g, "."
        import_text = import_text.replace /.py/g, ""
        if import_text != ""
          selection = editor.getLastSelection()
          selected_text = selection.getText()
          if selected_text != ""
            import_text = "from " + import_text + " import " + selected_text
          else
            split_text = import_text.split(".")
            import_text = "from " + split_text[0..-2].join(".") + " import " + split_text[-1..]
          atom.clipboard.write(import_text)
          atom.notifications.addInfo("Sniped:  " + import_text)
        break
  if import_text == ""
    atom.notifications.addWarning("Couldn't snipe import, current file not in an open project.")
