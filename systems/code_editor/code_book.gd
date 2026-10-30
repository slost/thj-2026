## Opens and closes the shared book sprite and code editor together.
## World map and battle both call this instead of copying the mount logic.
extends RefCounted


static func set_open(book: Node, editor: Node, open: bool) -> void:
	set_book_visible(book, open)
	set_editor_open(editor, open)


static func set_book_visible(book: Node, value: bool) -> void:
	if book == null or not is_instance_valid(book):
		return
	for child in book.get_children():
		if child.has_method("set_visible"):
			child.set_visible(value)
	if book is CanvasItem:
		(book as CanvasItem).visible = value


static func set_editor_open(editor: Node, open: bool) -> void:
	if editor == null or not is_instance_valid(editor):
		return
	if open:
		editor.call(&"open")
	else:
		editor.call(&"close")
