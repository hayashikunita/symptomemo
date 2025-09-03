import UIKit

enum PDFBuilder {
    static func makePDF(from: Date, to: Date, entries: [SymptomEntry], settings: AppSettings? = nil) -> URL {
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
                // 幅・高さは有限にクランプ
                let fullWidth = 595 as CGFloat
                let availableWidth = max(1, (fullWidth - margin*2).isFinite ? (fullWidth - margin*2) : 1)
                let rect = CGRect(x: margin.isFinite ? margin : 0,
                                  y: y.isFinite ? y : margin,
                                  width: availableWidth,
                                  height: 100_000) // 大きめの有限値
                let s = NSAttributedString(string: text, attributes: attrs.merging([.paragraphStyle: para]){ $1 })
                let size = s.boundingRect(with: CGSize(width: rect.width, height: rect.height),
                                          options: [.usesLineFragmentOrigin, .usesFontLeading],
                                          context: nil)
                // 高さが非有限ならフォールバック
                let measuredH = ceil(size.height.isFinite ? size.height : font.lineHeight)
                let safeH = min(max(measuredH, font.lineHeight), 100_000)
                let drawY = (y.isFinite ? y : margin)
                s.draw(in: CGRect(origin: CGPoint(x: rect.minX, y: drawY), size: CGSize(width: rect.width, height: safeH)))
                let newY = drawY + safeH + 10
                y = newY.isFinite ? newY : margin
            }

            // ヘッダ
            draw("症状経過まとめ（診療用）", font: .boldSystemFont(ofSize: 20))
            let df = DateFormatter(); df.locale = .current; df.dateStyle = .medium
            draw("期間: \(df.string(from: from)) 〜 \(df.string(from: to))", font: .systemFont(ofSize: 12), color: .secondaryLabel)
            y += 8
            if y.isFinite {
                ctx.cgContext.setStrokeColor(UIColor.separator.cgColor)
                ctx.cgContext.setLineWidth(1)
                ctx.cgContext.move(to: CGPoint(x: margin, y: y))
                ctx.cgContext.addLine(to: CGPoint(x: 595 - margin, y: y))
                ctx.cgContext.strokePath()
            } else {
                y = margin
            }
            y += 16

            let sorted = entries.sorted(by: { $0.date < $1.date })

            // AIセクション前付け
            let placeFront = ((settings?.pdfAIPlacement ?? 1) == 0)
            if placeFront {
                draw("AIサマリー", font: .boldSystemFont(ofSize: 16))
                let summary = AIPDFSummarizer.summaryText(from: from, to: to, entries: sorted)
                if !summary.isEmpty { draw(summary, font: .systemFont(ofSize: 12), color: .secondaryLabel) }
                y += 8
                if y.isFinite {
                    ctx.cgContext.setStrokeColor(UIColor.separator.cgColor)
                    ctx.cgContext.setLineWidth(1)
                    ctx.cgContext.move(to: CGPoint(x: margin, y: y))
                    ctx.cgContext.addLine(to: CGPoint(x: 595 - margin, y: y))
                    ctx.cgContext.strokePath()
                } else {
                    y = margin
                }
                y += 16
            }

            // 本文
            for e in sorted {
                let dateStr = df.string(from: e.date)
                var head = "\(dateStr)  /  重症度: \(e.severity)/10"
                if e.isImportant { head += "  [重要]" }
                if !e.medication.isEmpty { head += "  薬: \(e.medication)" }
                draw(head, font: .boldSystemFont(ofSize: 14))
                if !e.text.isEmpty { draw(e.text, font: .systemFont(ofSize: 13)) }
                if !placeFront {
                    if let short = e.aiAdviceShort, !short.isEmpty {
                        draw("重要ポイント（AI）：\n\(short)", font: .systemFont(ofSize: 12), color: .secondaryLabel)
                    } else if let full = e.aiAdvice, !full.isEmpty {
                        draw("AIアドバイス：\n\(full)", font: .systemFont(ofSize: 12), color: .secondaryLabel)
                    }
                }
                let nextY = y + 6
                y = nextY.isFinite ? nextY : margin
            }
        }
        return tmp
    }
}

enum AIPDFSummarizer {
    static func summaryText(from: Date, to: Date, entries: [SymptomEntry]) -> String {
        // 既存保存された短い版をつなげる。なければフル、どちらも無ければ空。
        let df = DateFormatter(); df.locale = .current; df.dateStyle = .medium
        var lines: [String] = []
        for e in entries {
            let dateStr = df.string(from: e.date)
            if let short = e.aiAdviceShort, !short.isEmpty {
                lines.append("◆ \(dateStr)\n\(short)")
            } else if let full = e.aiAdvice, !full.isEmpty {
                lines.append("◆ \(dateStr)\n\(full)")
            }
        }
        return lines.joined(separator: "\n\n")
    }
}
