import fitz  # PyMuPDF
import os

pdf_folder = r"C:\Users\Joey\Downloads\1000+ PDF_Invoice_Folder\1000+ PDF_Invoice_Folder"
output_folder = r"C:\Users\Joey\Downloads\1000+ PDF_Invoice_Folder\images"
os.makedirs(output_folder, exist_ok=True)

for pdf_file in os.listdir(pdf_folder):
    if pdf_file.endswith(".pdf"):
        pdf_path = os.path.join(pdf_folder, pdf_file)
        doc = fitz.open(pdf_path)
        for i, page in enumerate(doc):
            pix = page.get_pixmap(dpi=300)  # 300 dpi
            pix.save(os.path.join(output_folder, f"{pdf_file[:-4]}_page{i}.jpg"))
