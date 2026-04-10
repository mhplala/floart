// Floart/Views/MainWindowView.swift
import SwiftUI
import SwiftData

enum SidebarItem: String, CaseIterable {
    case reports = "Daily Reports"
    case history = "History"
}

struct MainWindowView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedSidebar: SidebarItem = .reports
    @State private var selectedReportDate: String?
    @State private var selectedInsight: InsightRecord?
    @State private var searchText = ""

    var body: some View {
        NavigationSplitView {
            sidebarView
                .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } content: {
            listView
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            detailView
        }
        .frame(minWidth: 800, minHeight: 500)
    }

    // MARK: - Sidebar (Left)

    private var sidebarView: some View {
        List(selection: $selectedSidebar) {
            Section {
                Label("Daily Reports", systemImage: "calendar")
                    .tag(SidebarItem.reports)
                Label("History", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    .tag(SidebarItem.history)
            }

            Section("Status") {
                HStack {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    Text("Running")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: - List (Middle)

    @ViewBuilder
    private var listView: some View {
        switch selectedSidebar {
        case .reports:
            reportListView
        case .history:
            historyListView
        }
    }

    // MARK: - Report List

    private var reportListView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Daily Reports")
                    .font(.title3.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            reportList
        }
    }

    private var reportList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(fetchedReports, id: \.date) { report in
                    ReportCard(report: report, isSelected: selectedReportDate == report.date)
                        .onTapGesture { selectedReportDate = report.date }
                }

                if fetchedReports.isEmpty {
                    emptyState(
                        icon: "calendar.badge.clock",
                        title: "No Reports Yet",
                        subtitle: "Daily reports are generated automatically each morning"
                    )
                }
            }
            .padding(12)
        }
    }

    private var fetchedReports: [DailyReport] {
        let descriptor = FetchDescriptor<DailyReport>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - History List (Today's insights)

    private var historyListView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Today's Insights")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text("\(fetchedTodayInsights.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if !fetchedTodayInsights.isEmpty {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.quaternary.opacity(0.5))

                Divider()
            }

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(filteredInsights) { record in
                        InsightCard(record: record, isSelected: selectedInsight?.id == record.id)
                            .onTapGesture { selectedInsight = record }
                    }

                    if filteredInsights.isEmpty {
                        emptyState(
                            icon: "text.magnifyingglass",
                            title: searchText.isEmpty ? "No Insights Yet" : "No Results",
                            subtitle: searchText.isEmpty ? "Insights appear as you work" : "Try a different search"
                        )
                    }
                }
                .padding(12)
            }
        }
    }

    private var fetchedTodayInsights: [InsightRecord] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let descriptor = FetchDescriptor<InsightRecord>(
            predicate: #Predicate { $0.timestamp >= startOfDay && $0.timestamp < endOfDay },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private var filteredInsights: [InsightRecord] {
        if searchText.isEmpty { return fetchedTodayInsights }
        let query = searchText.lowercased()
        return fetchedTodayInsights.filter {
            $0.summary.lowercased().contains(query) ||
            $0.rawOCRText.lowercased().contains(query)
        }
    }

    // MARK: - Detail (Right)

    @ViewBuilder
    private var detailView: some View {
        switch selectedSidebar {
        case .reports:
            if let date = selectedReportDate,
               let report = fetchedReports.first(where: { $0.date == date }) {
                ReportDetailView(report: report)
            } else {
                placeholderDetail(icon: "calendar", text: "Select a daily report")
            }
        case .history:
            if let record = selectedInsight {
                InsightDetailView(record: record)
            } else {
                placeholderDetail(icon: "clock", text: "Select an insight")
            }
        }
    }

    // MARK: - Helpers

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(.quaternary)
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private func placeholderDetail(icon: String, text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.quaternary)
            Text(text)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Report Card

struct ReportCard: View {
    let report: DailyReport
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(formattedDate)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(weekday)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Label("\(report.insightCount)", systemImage: "lightbulb")
                Label("\(report.meetingCount)", systemImage: "person.2")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if !report.content.isEmpty {
                Text(report.content.prefix(80) + "...")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .clipShape(.rect(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    private var formattedDate: String {
        // "2026-04-09" → "Apr 9"
        let parts = report.date.split(separator: "-")
        guard parts.count == 3, let month = Int(parts[1]), let day = Int(parts[2]) else { return report.date }
        let months = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return "\(months[month]) \(day)"
    }

    private var weekday: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: report.date) else { return "" }
        f.dateFormat = "EEEE"
        return f.string(from: date)
    }
}

// MARK: - Insight Card

struct InsightCard: View {
    let record: InsightRecord
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(timeString)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(record.appName.isEmpty ? record.aiProvider : record.appName)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }

            Text(record.summary)
                .font(.system(size: 12))
                .lineLimit(3)
        }
        .padding(10)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .clipShape(.rect(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: record.timestamp)
    }
}

// MARK: - Report Detail

struct ReportDetailView: View {
    let report: DailyReport

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(fullDate)
                            .font(.title2.weight(.bold))
                        HStack(spacing: 16) {
                            Label("\(report.insightCount) insights", systemImage: "lightbulb")
                            Label("\(report.meetingCount) meetings", systemImage: "person.2")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                Divider()

                // Report content
                Text(report.content)
                    .font(.body)
                    .lineSpacing(6)
                    .textSelection(.enabled)

                Spacer()
            }
            .padding(24)
        }
    }

    private var fullDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: report.date) else { return report.date }
        f.dateFormat = "EEEE, MMMM d, yyyy"
        return f.string(from: date)
    }
}

// MARK: - Insight Detail

struct InsightDetailView: View {
    let record: InsightRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Text(timeString)
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Text(record.aiProvider)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.quaternary)
                        .clipShape(Capsule())
                }

                Divider()

                // AI Analysis
                if !record.summary.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Analysis")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(record.summary)
                            .font(.body)
                            .lineSpacing(5)
                            .textSelection(.enabled)
                    }
                }

                Divider()

                // Original content
                if !record.rawOCRText.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Screen Content")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(record.rawOCRText)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineSpacing(4)
                            .textSelection(.enabled)
                    }
                }

                Spacer()
            }
            .padding(24)
        }
    }

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: record.timestamp)
    }
}
