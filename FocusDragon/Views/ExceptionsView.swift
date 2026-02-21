//
//  ExceptionsView.swift
//  FocusDragon
//

import SwiftUI

struct ExceptionsView: View {
    @ObservedObject var manager: BlockListManager
    @Environment(\.dismiss) private var dismiss

    @State private var showingURLSheet = false
    @State private var editingURLException: URLException?

    @State private var showingAppSheet = false
    @State private var editingAppException: AppException?

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Exceptions")
                            .font(AppTheme.titleFont(20))
                        Text("Allow specific paths or apps while blocking is active.")
                            .font(AppTheme.bodyFont(12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Done") { dismiss() }
                        .buttonStyle(SecondaryButtonStyle())
                }
                .padding()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        urlExceptionsSection
                        appExceptionsSection
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 560, minHeight: 560)
        .sheet(isPresented: $showingURLSheet) {
            URLExceptionEditor(
                exception: editingURLException,
                onSave: saveURLException
            )
        }
        .sheet(isPresented: $showingAppSheet) {
            AppExceptionEditor(
                exception: editingAppException,
                onSave: saveAppException
            )
        }
    }

    private var urlExceptionsSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("URL Exceptions")
                        .font(AppTheme.headerFont(15))
                    Spacer()
                    Button {
                        editingURLException = nil
                        showingURLSheet = true
                    } label: {
                        Label("Add", systemImage: "plus.circle")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .controlSize(.small)
                }

                Text("Allow specific paths on a blocked domain. These domains are removed from hosts-file blocking and rely on the browser extension.")
                    .font(AppTheme.bodyFont(11))
                    .foregroundColor(.secondary)

                if manager.urlExceptions.isEmpty {
                    Text("No URL exceptions yet.")
                        .font(AppTheme.bodyFont(11))
                        .foregroundColor(.secondary)
                } else {
                    ForEach(manager.urlExceptions) { exception in
                        AppCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(exception.domain)
                                        .font(AppTheme.headerFont(13))
                                    Text(exception.allowedPaths.joined(separator: ", "))
                                        .font(AppTheme.bodyFont(11))
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                Button("Edit") {
                                    editingURLException = exception
                                    showingURLSheet = true
                                }
                                .buttonStyle(SecondaryButtonStyle())
                                .controlSize(.small)
                                Button(role: .destructive) {
                                    manager.urlExceptions.removeAll { $0.id == exception.id }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(SecondaryButtonStyle())
                                .controlSize(.small)
                            }
                        }
                    }
                }
            }
        }
    }

    private var appExceptionsSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("App Exceptions")
                        .font(AppTheme.headerFont(15))
                    Spacer()
                    Button {
                        editingAppException = nil
                        showingAppSheet = true
                    } label: {
                        Label("Add", systemImage: "plus.circle")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .controlSize(.small)
                }

                Text("Allow specific apps always or on a schedule while blocking is active.")
                    .font(AppTheme.bodyFont(11))
                    .foregroundColor(.secondary)

                if manager.appExceptions.isEmpty {
                    Text("No app exceptions yet.")
                        .font(AppTheme.bodyFont(11))
                        .foregroundColor(.secondary)
                } else {
                    ForEach(manager.appExceptions) { exception in
                        AppCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(exception.appName)
                                        .font(AppTheme.headerFont(13))
                                    Text(exception.bundleIdentifier)
                                        .font(AppTheme.bodyFont(11))
                                        .foregroundColor(.secondary)
                                    Text(exception.alwaysAllow ? "Always allowed" : scheduleSummary(exception.schedules))
                                        .font(AppTheme.bodyFont(10))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button("Edit") {
                                    editingAppException = exception
                                    showingAppSheet = true
                                }
                                .buttonStyle(SecondaryButtonStyle())
                                .controlSize(.small)
                                Button(role: .destructive) {
                                    manager.appExceptions.removeAll { $0.id == exception.id }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(SecondaryButtonStyle())
                                .controlSize(.small)
                            }
                        }
                    }
                }
            }
        }
    }

    private func scheduleSummary(_ schedules: [ExceptionSchedule]) -> String {
        if schedules.isEmpty { return "No schedule set" }
        if schedules.count == 1, let s = schedules.first {
            return "Allowed \(s.startHour):\(String(format: "%02d", s.startMinute))–\(s.endHour):\(String(format: "%02d", s.endMinute))"
        }
        return "Allowed on \(schedules.count) time windows"
    }

    private func saveURLException(_ exception: URLException) {
        if let existing = manager.urlExceptions.firstIndex(where: { $0.id == exception.id }) {
            manager.urlExceptions[existing] = exception
        } else {
            manager.urlExceptions.append(exception)
        }
    }

    private func saveAppException(_ exception: AppException) {
        if let existing = manager.appExceptions.firstIndex(where: { $0.id == exception.id }) {
            manager.appExceptions[existing] = exception
        } else {
            manager.appExceptions.append(exception)
        }
    }
}

// MARK: - URL Exception Editor

private struct URLExceptionEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var domain: String
    @State private var pathsText: String
    private let existingID: UUID?
    private let onSave: (URLException) -> Void

    init(exception: URLException?, onSave: @escaping (URLException) -> Void) {
        self.existingID = exception?.id
        _domain = State(initialValue: exception?.domain ?? "")
        _pathsText = State(initialValue: exception?.allowedPaths.joined(separator: "\n") ?? "")
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(existingID == nil ? "Add URL Exception" : "Edit URL Exception")
                .font(AppTheme.headerFont(16))

            TextField("Domain (e.g. reddit.com)", text: $domain)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 6) {
                Text("Allowed paths (one per line)")
                    .font(AppTheme.bodyFont(11))
                    .foregroundColor(.secondary)
                TextEditor(text: $pathsText)
                    .frame(minHeight: 120)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2)))
            }

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save") {
                    let paths = pathsText
                        .split(whereSeparator: \.isNewline)
                        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }

                    let exception = URLException(
                        id: existingID ?? UUID(),
                        domain: domain.trimmingCharacters(in: .whitespacesAndNewlines),
                        allowedPaths: paths
                    )
                    onSave(exception)
                    dismiss()
                }
                .buttonStyle(PrimaryGlowButtonStyle())
                .disabled(domain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || pathsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(minWidth: 420, minHeight: 300)
    }
}

// MARK: - App Exception Editor

private struct AppExceptionEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var appName: String
    @State private var bundleID: String
    @State private var alwaysAllow: Bool
    @State private var schedules: [ExceptionSchedule]
    @State private var showingScheduleEditor = false
    @State private var editingScheduleIndex: Int?

    private let existingID: UUID?
    private let onSave: (AppException) -> Void

    init(exception: AppException?, onSave: @escaping (AppException) -> Void) {
        self.existingID = exception?.id
        _appName = State(initialValue: exception?.appName ?? "")
        _bundleID = State(initialValue: exception?.bundleIdentifier ?? "")
        _alwaysAllow = State(initialValue: exception?.alwaysAllow ?? true)
        _schedules = State(initialValue: exception?.schedules ?? [])
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(existingID == nil ? "Add App Exception" : "Edit App Exception")
                .font(AppTheme.headerFont(16))

            if appName.isEmpty {
                Button("Select Application") {
                    AppSelector.shared.selectApplication { item in
                        guard let item else { return }
                        appName = item.appName ?? item.displayName
                        bundleID = item.bundleIdentifier ?? ""
                    }
                }
                .buttonStyle(.borderedProminent)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(appName).fontWeight(.medium)
                    Text(bundleID).font(.caption).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Toggle("Always allow", isOn: $alwaysAllow)
                .onChange(of: alwaysAllow) { value in
                    if value {
                        schedules.removeAll()
                    }
                }

            if !alwaysAllow {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Allowed time windows").font(AppTheme.bodyFont(12))
                        Spacer()
                        Button {
                            editingScheduleIndex = nil
                            showingScheduleEditor = true
                        } label: {
                            Label("Add", systemImage: "plus.circle")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .controlSize(.small)
                    }

                    if schedules.isEmpty {
                        Text("No schedules yet.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(schedules.enumerated()), id: \.offset) { index, schedule in
                            HStack {
                                Text(scheduleLabel(schedule))
                                    .font(AppTheme.bodyFont(11))
                                Spacer()
                                Button("Edit") {
                                    editingScheduleIndex = index
                                    showingScheduleEditor = true
                                }
                                .buttonStyle(SecondaryButtonStyle())
                                .controlSize(.small)
                                Button(role: .destructive) {
                                    schedules.remove(at: index)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(SecondaryButtonStyle())
                                .controlSize(.small)
                            }
                            .padding(8)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                        }
                    }
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save") {
                    let exception = AppException(
                        id: existingID ?? UUID(),
                        bundleIdentifier: bundleID,
                        appName: appName,
                        alwaysAllow: alwaysAllow,
                        schedules: schedules
                    )
                    onSave(exception)
                    dismiss()
                }
                .buttonStyle(PrimaryGlowButtonStyle())
                .disabled(bundleID.isEmpty || appName.isEmpty)
            }
        }
        .padding()
        .frame(minWidth: 460, minHeight: 360)
        .sheet(isPresented: $showingScheduleEditor) {
            ExceptionScheduleEditor(
                schedule: editingScheduleIndex.flatMap { schedules[$0] },
                onSave: { schedule in
                    if let idx = editingScheduleIndex {
                        schedules[idx] = schedule
                    } else {
                        schedules.append(schedule)
                    }
                }
            )
        }
    }

    private func scheduleLabel(_ schedule: ExceptionSchedule) -> String {
        let days = schedule.days.sorted().map { weekdayName($0) }.joined(separator: ", ")
        let start = String(format: "%02d:%02d", schedule.startHour, schedule.startMinute)
        let end = String(format: "%02d:%02d", schedule.endHour, schedule.endMinute)
        return "\(days) \(start)–\(end)"
    }

    private func weekdayName(_ value: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        let symbols = formatter.shortWeekdaySymbols ?? ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
        let index = max(1, min(7, value)) - 1
        return symbols[index]
    }
}

// MARK: - Schedule Editor

private struct ExceptionScheduleEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDays: Set<Int>
    @State private var startTime: Date
    @State private var endTime: Date

    private let onSave: (ExceptionSchedule) -> Void

    init(schedule: ExceptionSchedule?, onSave: @escaping (ExceptionSchedule) -> Void) {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(bySettingHour: schedule?.startHour ?? 9,
                                  minute: schedule?.startMinute ?? 0,
                                  second: 0, of: now) ?? now
        let end = calendar.date(bySettingHour: schedule?.endHour ?? 17,
                                minute: schedule?.endMinute ?? 0,
                                second: 0, of: now) ?? now
        _selectedDays = State(initialValue: schedule?.days ?? [2,3,4,5,6])
        _startTime = State(initialValue: start)
        _endTime = State(initialValue: end)
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Allowed Time Window")
                .font(AppTheme.headerFont(16))

            daysPicker

            HStack {
                DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                DatePicker("End", selection: $endTime, displayedComponents: .hourAndMinute)
            }

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save") {
                    let calendar = Calendar.current
                    let start = calendar.dateComponents([.hour, .minute], from: startTime)
                    let end = calendar.dateComponents([.hour, .minute], from: endTime)

                    let schedule = ExceptionSchedule(
                        days: selectedDays,
                        startHour: start.hour ?? 0,
                        startMinute: start.minute ?? 0,
                        endHour: end.hour ?? 0,
                        endMinute: end.minute ?? 0
                    )
                    onSave(schedule)
                    dismiss()
                }
                .buttonStyle(PrimaryGlowButtonStyle())
                .disabled(selectedDays.isEmpty)
            }
        }
        .padding()
        .frame(minWidth: 420, minHeight: 260)
    }

    private var daysPicker: some View {
        let symbols = Calendar.current.shortWeekdaySymbols ?? ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
        return HStack {
            ForEach(0..<7, id: \.self) { index in
                let weekday = index + 1
                Toggle(symbols[index], isOn: Binding(
                    get: { selectedDays.contains(weekday) },
                    set: { isOn in
                        if isOn {
                            selectedDays.insert(weekday)
                        } else {
                            selectedDays.remove(weekday)
                        }
                    }
                ))
                .toggleStyle(.button)
            }
        }
    }
}
