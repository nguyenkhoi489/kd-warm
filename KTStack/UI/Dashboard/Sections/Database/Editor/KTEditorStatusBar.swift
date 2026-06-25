import SwiftUI
import KTStackKit

struct KTEditorStatusBar: View {
    let result: QueryResult

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 5) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 10))
                Text("\(result.rowCount) row\(result.rowCount == 1 ? "" : "s")").font(.jbMono(11))
            }
            .foregroundStyle(KTEditorTheme.Status.running)

            if result.truncated {
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 10))
                    Text("truncated to \(SQLAutoLimit.defaultMax) rows").font(.jbMono(11))
                }
                .foregroundStyle(KTEditorTheme.Status.warning)
            }
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KTEditorTheme.content2)
        .overlay(alignment: .top) { Rectangle().fill(KTEditorTheme.separator).frame(height: 0.5) }
    }
}
