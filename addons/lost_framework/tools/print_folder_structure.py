import os
import tkinter as tk
from tkinter import filedialog


def print_tree(root_path: str, prefix: str = ""):
	"""
	Recursively print folder structure as a tree.
	"""
	items = sorted(os.listdir(root_path))
	files = [i for i in items if os.path.isfile(os.path.join(root_path, i))]
	dirs = [i for i in items if os.path.isdir(os.path.join(root_path, i))]

	all_items = dirs + files

	for index, name in enumerate(all_items):
		full_path = os.path.join(root_path, name)
		is_last = index == len(all_items) - 1

		connector = "└── " if is_last else "├── "
		print(prefix + connector + name)

		if os.path.isdir(full_path):
			extension = "    " if is_last else "│   "
			print_tree(full_path, prefix + extension)


def main():
	# Hide root window
	root = tk.Tk()
	root.withdraw()

	folder_path = filedialog.askdirectory(title="Select a folder")

	if not folder_path:
		print("No folder selected.")
		return

	print(f"\n📁 {os.path.basename(folder_path)}")
	print_tree(folder_path)


if __name__ == "__main__":
	main()
