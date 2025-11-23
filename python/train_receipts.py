import os
import sys
import json
import shutil
import subprocess
import argparse
from pathlib import Path
import cv2
import numpy as np

CLASSES = [
    "company_name",
    "phone_number",
    "product",
    "quantity",
    "unit_price",
    "receipt_id",
]

def run(cmd, cwd=None):
    p = subprocess.Popen(cmd, cwd=cwd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    out, _ = p.communicate()
    rc = p.returncode
    if rc != 0:
        raise RuntimeError(out.decode(errors="ignore"))
    return out.decode(errors="ignore")

def pip_install(packages):
    for pkg in packages:
        run(f"{sys.executable} -m pip install -q {pkg}")

def is_colab():
    return "google.colab" in sys.modules

def ensure_yolov5_repo(base_dir):
    repo_dir = Path(base_dir) / "yolov5"
    if not repo_dir.exists():
        run("git clone https://github.com/ultralytics/yolov5", cwd=base_dir)
    req = repo_dir / "requirements.txt"
    if req.exists():
        run(f"{sys.executable} -m pip install -r {req}")
    return str(repo_dir)

def write_yaml(dataset_root, yaml_path):
    path_str = str(Path(dataset_root).resolve())
    names_str = ", ".join([f"'{n}'" for n in CLASSES])
    content = (
        f"path: {path_str}\n"
        f"train: images/train\n"
        f"val: images/val\n"
        f"names: [{names_str}]\n"
    )
    p = Path(yaml_path)
    p.parent.mkdir(parents=True, exist_ok=True)
    with open(p, "w", encoding="utf-8") as f:
        f.write(content)

def train(dataset_yaml, repo_dir, weights="yolov5s.pt", img=640, batch=16, epochs=100, name="receipt_det"):
    cmd = (
        f"{sys.executable} train.py --img {img} --batch {batch} --epochs {epochs} "
        f"--data {dataset_yaml} --weights {weights} --name {name}"
    )
    run(cmd, cwd=repo_dir)
    return str(Path(repo_dir) / "runs" / "train" / name / "weights" / "best.pt")

def detect(repo_dir, weights_path, image_path, img=640, conf=0.25, project_name="receipt_infer"):
    out_dir = Path(repo_dir) / "runs" / "detect" / project_name
    if out_dir.exists():
        shutil.rmtree(out_dir)
    cmd = (
        f"{sys.executable} detect.py --weights {weights_path} --img {img} --conf {conf} "
        f"--source {image_path} --save-txt --save-conf --project runs/detect --name {project_name}"
    )
    run(cmd, cwd=repo_dir)
    labels_dir = out_dir / "labels"
    img_stem = Path(image_path).stem
    label_file = labels_dir / f"{img_stem}.txt"
    if not label_file.exists():
        return []
    return parse_detect_labels(str(label_file), image_path)

def parse_detect_labels(label_txt_path, image_path):
    img = cv2.imread(image_path)
    h, w = img.shape[:2]
    dets = []
    with open(label_txt_path, "r", encoding="utf-8") as f:
        for line in f.read().strip().splitlines():
            parts = line.strip().split()
            if len(parts) < 5:
                continue
            cls = int(parts[0])
            cx = float(parts[1]) * w
            cy = float(parts[2]) * h
            bw = float(parts[3]) * w
            bh = float(parts[4]) * h
            conf = float(parts[5]) if len(parts) > 5 else 0.0
            x1 = int(max(0, cx - bw / 2))
            y1 = int(max(0, cy - bh / 2))
            x2 = int(min(w - 1, cx + bw / 2))
            y2 = int(min(h - 1, cy + bh / 2))
            dets.append({"cls": cls, "name": CLASSES[cls], "bbox": [x1, y1, x2, y2], "conf": conf})
    return dets

def ocr_text(image):
    from paddleocr import PaddleOCR
    ocr = PaddleOCR(use_angle_cls=True, lang="en", use_gpu=False)
    res = ocr.ocr(image, cls=True)
    texts = []
    if isinstance(res, list):
        for block in res:
            if isinstance(block, list):
                for line in block:
                    if len(line) >= 2 and isinstance(line[1], tuple):
                        texts.append(line[1][0])
    return " ".join(texts).strip()

def crop(image, box):
    x1, y1, x2, y2 = box
    return image[y1:y2, x1:x2]

def iou_y(a, b):
    ay1, ay2 = a[1], a[3]
    by1, by2 = b[1], b[3]
    inter = max(0, min(ay2, by2) - max(ay1, by1))
    denom = (ay2 - ay1) + (by2 - by1) - inter
    return inter / denom if denom > 0 else 0.0

def pair_line_items(products, quantities, prices):
    items = []
    quantities_sorted = sorted(quantities, key=lambda d: (d["bbox"][1]+d["bbox"][3])/2)
    prices_sorted = sorted(prices, key=lambda d: (d["bbox"][1]+d["bbox"][3])/2)
    for p in sorted(products, key=lambda d: (d["bbox"][1]+d["bbox"][3])/2):
        py = p["bbox"]
        best_q = None
        best_q_score = 0
        for q in quantities_sorted:
            score = iou_y(py, q["bbox"])
            if score > best_q_score:
                best_q_score = score
                best_q = q
        best_u = None
        best_u_score = 0
        for u in prices_sorted:
            score = iou_y(py, u["bbox"])
            if score > best_u_score:
                best_u_score = score
                best_u = u
        items.append({"product_det": p, "quantity_det": best_q, "unit_price_det": best_u})
    return items

def extract_structured(image_path, detections):
    img = cv2.imread(image_path)
    singles = {"company_name": None, "phone_number": None, "receipt_id": None}
    for k in singles.keys():
        c = [d for d in detections if d["name"] == k]
        c = sorted(c, key=lambda d: d["conf"], reverse=True)
        singles[k] = ocr_text(crop(img, c[0]["bbox"])) if c else None
    products = [d for d in detections if d["name"] == "product"]
    quantities = [d for d in detections if d["name"] == "quantity"]
    unit_prices = [d for d in detections if d["name"] == "unit_price"]
    pairs = pair_line_items(products, quantities, unit_prices)
    items = []
    for pr in pairs:
        p_img = crop(img, pr["product_det"]["bbox"]) if pr["product_det"] else None
        q_img = crop(img, pr["quantity_det"]["bbox"]) if pr["quantity_det"] else None
        u_img = crop(img, pr["unit_price_det"]["bbox"]) if pr["unit_price_det"] else None
        p_txt = ocr_text(p_img) if p_img is not None else None
        q_txt = ocr_text(q_img) if q_img is not None else None
        u_txt = ocr_text(u_img) if u_img is not None else None
        items.append({"product": p_txt, "quantity": q_txt, "unit_price": u_txt})
    return {
        "company_name": singles["company_name"],
        "phone_number": singles["phone_number"],
        "receipt_id": singles["receipt_id"],
        "items": items,
    }

def visualize_detections(image_path, detections, out_path):
    img = cv2.imread(image_path)
    for d in detections:
        x1, y1, x2, y2 = d["bbox"]
        name = d.get("name", "")
        conf = d.get("conf", 0.0)
        cv2.rectangle(img, (x1, y1), (x2, y2), (0, 0, 255), 2)
        label = f"{name} {conf:.2f}"
        (tw, th), _ = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.6, 2)
        cv2.rectangle(img, (x1, y1 - th - 6), (x1 + tw + 6, y1), (0, 0, 255), -1)
        cv2.putText(img, label, (x1 + 3, y1 - 6), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)
    cv2.imwrite(out_path, img)

def find_image_by_stem(images_dir, stem):
    p = Path(images_dir)
    for ext in (".jpg", ".jpeg", ".png", ".bmp", ".webp"):
        cand = list(p.rglob(f"{stem}{ext}"))
        if cand:
            return str(cand[0])
    return None

def detect_dir(repo_dir, weights_path, images_dir, img=640, conf=0.25, project_name="receipt_test", visualize=False):
    out_dir = Path(repo_dir) / "runs" / "detect" / project_name
    if out_dir.exists():
        shutil.rmtree(out_dir)
    cmd = (
        f"{sys.executable} detect.py --weights {weights_path} --img {img} --conf {conf} "
        f"--source {images_dir} --save-txt --save-conf --project runs/detect --name {project_name}"
    )
    run(cmd, cwd=repo_dir)
    labels_dir = out_dir / "labels"
    json_dir = out_dir / "json"
    viz_dir = out_dir / "viz"
    json_dir.mkdir(parents=True, exist_ok=True)
    if visualize:
        viz_dir.mkdir(parents=True, exist_ok=True)
    for label_file in labels_dir.glob("*.txt"):
        stem = label_file.stem
        original_image = find_image_by_stem(images_dir, stem)
        if original_image is None:
            # Fallback to the copied image in out_dir
            possible = list(out_dir.glob(f"{stem}.*"))
            original_image = str(possible[0]) if possible else None
        if original_image is None:
            continue
        dets = parse_detect_labels(str(label_file), original_image)
        result = extract_structured(original_image, dets)
        with open(json_dir / f"{stem}.json", "w", encoding="utf-8") as f:
            json.dump(result, f, ensure_ascii=False, indent=2)
        if visualize:
            visualize_detections(original_image, dets, str(viz_dir / f"{stem}.jpg"))

def validate_dataset(dataset_root):
    root = Path(dataset_root)
    issues = []
    for split in ("train", "val"):
        img_dir = root / "images" / split
        lbl_dir = root / "labels" / split
        if not img_dir.exists():
            issues.append(f"missing images/{split}")
        if not lbl_dir.exists():
            issues.append(f"missing labels/{split}")
        for txt in lbl_dir.rglob("*.txt"):
            with open(txt, "r", encoding="utf-8") as f:
                for ln in f.read().strip().splitlines():
                    parts = ln.split()
                    if not parts:
                        continue
                    try:
                        cid = int(parts[0])
                        if cid < 0 or cid >= len(CLASSES):
                            issues.append(f"bad class id {cid} in {txt}")
                    except Exception:
                        issues.append(f"invalid line in {txt}: {ln}")
    return issues

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["train", "infer", "test", "validate"]) 
    default_root = "/content/data/receipts" if is_colab() else str(Path(__file__).parent / "data" / "receipts")
    parser.add_argument("dataset_root", nargs="?", default=default_root)
    parser.add_argument("image_or_dir", nargs="?", default="")
    parser.add_argument("--epochs", type=int, default=100)
    parser.add_argument("--batch", type=int, default=16)
    parser.add_argument("--img", type=int, default=640)
    parser.add_argument("--conf", type=float, default=0.25)
    parser.add_argument("--visualize", action="store_true")
    args = parser.parse_args()

    base = "/content" if is_colab() else str(Path(__file__).parent.resolve())
    Path(base).mkdir(parents=True, exist_ok=True)
    pip_install(["opencv-python", "paddleocr", "numpy"])
    try:
        pip_install(["paddlepaddle==2.6.1"])
    except Exception:
        pass
    repo_dir = ensure_yolov5_repo(base)

    yaml_path = str(Path(base) / "data" / "receipts.yaml")
    Path(Path(yaml_path).parent).mkdir(parents=True, exist_ok=True)
    write_yaml(args.dataset_root, yaml_path)

    if args.mode == "train":
        best = train(yaml_path, repo_dir, img=args.img, batch=args.batch, epochs=args.epochs, name="receipt_det")
        print(best)
        return

    if args.mode == "infer":
        best_path = str(Path(repo_dir) / "runs" / "train" / "receipt_det" / "weights" / "best.pt")
        if not Path(best_path).exists():
            raise FileNotFoundError(best_path)
        if not args.image_or_dir:
            raise ValueError("image path required for infer")
        dets = detect(repo_dir, best_path, args.image_or_dir, img=args.img, conf=args.conf, project_name="receipt_infer")
        result = extract_structured(args.image_or_dir, dets)
        print(json.dumps(result, ensure_ascii=False))
        return

    if args.mode == "test":
        best_path = str(Path(repo_dir) / "runs" / "train" / "receipt_det" / "weights" / "best.pt")
        if not Path(best_path).exists():
            raise FileNotFoundError(best_path)
        if not args.image_or_dir:
            raise ValueError("images directory required for test")
        detect_dir(repo_dir, best_path, args.image_or_dir, img=args.img, conf=args.conf, project_name="receipt_test", visualize=args.visualize)
        print(str(Path(repo_dir) / "runs" / "detect" / "receipt_test"))
        return

    if args.mode == "validate":
        issues = validate_dataset(args.dataset_root)
        print(json.dumps({"issues": issues}, ensure_ascii=False))
        return

if __name__ == "__main__":
    main()