import SwiftUI

enum TimezonerTheme {
    static let popoverWidth: CGFloat = 584
    static let headerHeight: CGFloat = 74
    static let footerHeight: CGFloat = 52
    static let dividerThickness: CGFloat = 1
    static let headerPadding: CGFloat = 18
    static let rowListHorizontalPadding: CGFloat = 14
    static let pinnedLocalVerticalPadding: CGFloat = 12
    static let comparisonVerticalPadding: CGFloat = 10
    static let comparisonRowSpacing: CGFloat = 10
    static let visibleComparisonRowCount = 2
    static let rowHeight: CGFloat = 174
    static var pinnedLocalSectionHeight: CGFloat {
        return rowHeight + (pinnedLocalVerticalPadding * 2)
    }
    static var comparisonScrollableHeight: CGFloat {
        return (rowHeight * CGFloat(visibleComparisonRowCount))
            + comparisonRowSpacing
    }
    static var comparisonViewportHeight: CGFloat {
        return comparisonScrollableHeight
            + (comparisonVerticalPadding * 2)
    }
    static var popoverHeight: CGFloat {
        return headerHeight
            + dividerThickness
            + pinnedLocalSectionHeight
            + comparisonViewportHeight
            + dividerThickness
            + footerHeight
    }
    static let rowPadding: CGFloat = 14
    static let rowSpacing: CGFloat = 12
    static let cornerRadius: CGFloat = 12
    static let controlCornerRadius: CGFloat = 7
    static let zoneColumnWidth: CGFloat = 254
    static let timeControlsWidth: CGFloat = 216
    static let endpointColumnWidth: CGFloat = 92
    static let rangeSummaryWidth: CGFloat = 184
    static let synchronizationLabelWidth: CGFloat = 220
    static let timeFieldWidth: CGFloat = 64
    static let timeFieldHeight: CGFloat = 22
    static let rowActionWidth: CGFloat = 20
    static let inlineActionSize: CGFloat = 18
    static let endpointHeaderHeight: CGFloat = 18
    static let rowNameFieldHeight: CGFloat = 16
    static let sliderHeight: CGFloat = 46
    static let sliderHandleSize: CGFloat = 14
    static let sliderHitSize: CGFloat = 30
    static let coincidentHandleOffset: CGFloat = 10
    static let coincidentHandleHitSize: CGFloat = 20
    static let sliderTrackHeight: CGFloat = 5
    static let currentTimeHoverTargetWidth: CGFloat = 18
    static let currentTimeHoverTargetHeight: CGFloat = 32
    static let currentTimeHoverLabelWidth: CGFloat = 42
    static let currentTimeHoverVerticalOffset: CGFloat = -26
    static let currentTimeHoverCornerRadius: CGFloat = 6

    static let accent = Color(red: 0.40, green: 0.34, blue: 0.96)
    static let secondaryAccent = Color(red: 0.13, green: 0.65, blue: 0.85)
    static let localBackground = accent.opacity(0.085)
    static let rowBackground = Color.primary.opacity(0.035)
    static let disabledBackground = Color.primary.opacity(0.02)
    static let warning = Color.orange
    static let currentTimeMarker = Color(red: 0.97, green: 0.39, blue: 0.31)
}
