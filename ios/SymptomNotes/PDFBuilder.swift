import UIKit

enum PDFBuilder {
    static func makePDF(from: Date, to: Date, entries: [SymptomEntry]) -> URL {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842)) // A4 @72dpi
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("symptom_summary.pdf")
        try? FileManager.default.removeItem(at: tmp)
        try? renderer.writePDF(to: tmp) { ctx in
            ctx.beginPage()
            let margin: CGFloat = 32
            var y: CGFloat = margin

            func draw(_ text: String, font: UIFont, color: UIColor = .label) {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color
                ]
                let para = NSMutableParagraphStyle(); para.lineBreakMode = .byWordWrapping
                let rect = CGRect(x: margin, y: y, width: 595 - margin*2, height: .greatestFiniteMagnitude)
                let s = NSAttributedString(string: text, attributes: attrs.merging([.paragraphStyle: para]){ $1 })
                let size = s.boundingRect(with: CGSize(width: rect.width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin,.usesFontLeading], context: nil)
                s.draw(in: CGRect(origin: CGPoint(x: rect.minX, y: y), size: CGSize(width: rect.width, height: ceil(size.height))))
                y += ceil(size.height) + 10
            }

            // ヘッダ
            draw("症状経過まとめ（診療用）", font: .boldSystemFont(ofSize: 20))
            let df = DateFormatter(); df.locale = .current; df.dateStyle = .medium
            draw("期間: \(df.string(from: from)) 〜 \(df.string(from: to))", font: .systemFont(ofSize: 12), color: .secondaryLabel)
            y += 8
            ctx.cgContext.setStrokeColor(UIColor.separator.cgColor)
            ctx.cgContext.setLineWidth(1)
            ctx.cgContext.move(to: CGPoint(x: margin, y: y))
            ctx.cgContext.addLine(to: CGPoint(x: 595 - margin, y: y))
            ctx.cgContext.strokePath()
            y += 16

            // 本文
            for e in entries.sorted(by: { $0.date < $1.date }) {
                let dateStr = df.string(from: e.date)
                var head = "\(dateStr)  /  重症度: \(e.severity)/10"
                if e.isImportant { head += "  [重要]" }
                if !e.medication.isEmpty { head += "  薬: \(e.medication)" }
                draw(head, font: .boldSystemFont(ofSize: 14))
                if !e.text.isEmpty { draw(e.text, font: .systemFont(ofSize: 13)) }
                y += 6
            }
        }
        return tmp
    }
}
