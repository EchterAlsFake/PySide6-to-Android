from PySide6.QtWidgets import QApplication, QLabel

def main():
    app = QApplication([])
    label = QLabel("Hello World")
    label.show()
    app.exec()

if __name__ == "__main__":
    main()