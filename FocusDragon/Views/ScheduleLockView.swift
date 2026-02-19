import SwiftUI

struct ScheduleLockView: View {
    @StateObject private var controller = ScheduleLockController.shared
    @State private var showingAddSchedule = false

    var body: some View {
        VStack(spacing: 20) {
            headerSection

            if controller.isActive, let active = controller.activeSchedule {
                activeScheduleCard(active)
            }

            if controller.nextActivation != nil {
                nextActivationCard
            }

            schedulesList

            addScheduleButton
        }
        .padding()
        .sheet(isPresented: $showingAddSchedule) {
            ScheduleEditorView(schedule: nil)
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Schedule Lock")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Automatic blocking during specific times")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if controller.isActive {
                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Active")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
    }

    private func activeScheduleCard(_ schedule: ScheduleRule) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.green)
                Text("Currently Active")
                    .font(.headline)
                    .foregroundColor(.green)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(schedule.name)
                    .font(.title3)
                    .fontWeight(.semibold)

                Text(schedule.formattedTimeRange)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(schedule.formattedDays)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
    }

    private var nextActivationCard: some View {
        Group {
            if let next = controller.nextActivation {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.blue)

                    VStack(alignment: .leading) {
                        Text("Next Activation")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(formatDate(next))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    Spacer()
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }

    private var schedulesList: some View {
        VStack(spacing: 10) {
            if controller.schedules.isEmpty {
                emptyState
            } else {
                ForEach(controller.schedules) { schedule in
                    ScheduleRow(schedule: schedule)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 15) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 50))
                .foregroundColor(.gray)

            Text("No Schedules")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Create a schedule to automatically activate blocking")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 30)
    }

    private var addScheduleButton: some View {
        Menu {
            Button("Custom Schedule") {
                showingAddSchedule = true
            }

            Divider()

            Button("Work Hours (9 AM - 5 PM)") {
                controller.addSchedule(controller.createWorkHoursSchedule())
            }

            Button("Evening Focus (6 PM - 10 PM)") {
                controller.addSchedule(controller.createEveningSchedule())
            }

            Button("Study Time (2 PM - 6 PM)") {
                controller.addSchedule(controller.createStudySchedule())
            }
        } label: {
            Label("Add Schedule", systemImage: "plus.circle.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct ScheduleRow: View {
    let schedule: ScheduleRule
    @StateObject private var controller = ScheduleLockController.shared

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(schedule.name)
                    .font(.headline)

                Text(schedule.formattedTimeRange)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(schedule.formattedDays)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { schedule.isEnabled },
                set: { _ in controller.toggleSchedule(schedule) }
            ))
            .labelsHidden()
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct ScheduleEditorView: View {
    let schedule: ScheduleRule?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller = ScheduleLockController.shared

    @State private var name: String = ""
    @State private var startHour: Int = 9
    @State private var startMinute: Int = 0
    @State private var endHour: Int = 17
    @State private var endMinute: Int = 0
    @State private var selectedDays: Set<Weekday> = Weekday.weekdays

    var body: some View {
        VStack(spacing: 20) {
            Text("Configure Schedule")
                .font(.title2)
                .fontWeight(.semibold)

            TextField("Schedule Name", text: $name)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading) {
                Text("Start Time")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack {
                    Picker("Hour", selection: $startHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(String(format: "%02d", hour)).tag(hour)
                        }
                    }
                    .frame(width: 80)

                    Text(":")

                    Picker("Minute", selection: $startMinute) {
                        ForEach(0..<60, id: \.self) { minute in
                            Text(String(format: "%02d", minute)).tag(minute)
                        }
                    }
                    .frame(width: 80)
                }
            }

            VStack(alignment: .leading) {
                Text("End Time")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack {
                    Picker("Hour", selection: $endHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(String(format: "%02d", hour)).tag(hour)
                        }
                    }
                    .frame(width: 80)

                    Text(":")

                    Picker("Minute", selection: $endMinute) {
                        ForEach(0..<60, id: \.self) { minute in
                            Text(String(format: "%02d", minute)).tag(minute)
                        }
                    }
                    .frame(width: 80)
                }
            }

            VStack(alignment: .leading) {
                Text("Days")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]) {
                    ForEach(Weekday.allCases, id: \.self) { day in
                        Toggle(day.shortName, isOn: Binding(
                            get: { selectedDays.contains(day) },
                            set: { isOn in
                                if isOn {
                                    selectedDays.insert(day)
                                } else {
                                    selectedDays.remove(day)
                                }
                            }
                        ))
                        .toggleStyle(.button)
                    }
                }

                HStack(spacing: 10) {
                    Button("Weekdays") {
                        selectedDays = Weekday.weekdays
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Weekends") {
                        selectedDays = Weekday.weekends
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Every Day") {
                        selectedDays = Weekday.allDays
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.top, 5)
            }

            Spacer()

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Save") {
                    saveSchedule()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || selectedDays.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 600)
        .onAppear {
            if let schedule = schedule {
                name = schedule.name
                startHour = schedule.startTime.hour ?? 9
                startMinute = schedule.startTime.minute ?? 0
                endHour = schedule.endTime.hour ?? 17
                endMinute = schedule.endTime.minute ?? 0
                selectedDays = schedule.days
            }
        }
    }

    private func saveSchedule() {
        var startTime = DateComponents()
        startTime.hour = startHour
        startTime.minute = startMinute

        var endTime = DateComponents()
        endTime.hour = endHour
        endTime.minute = endMinute

        if let existing = schedule {
            var updated = existing
            updated.name = name
            updated.startTime = startTime
            updated.endTime = endTime
            updated.days = selectedDays
            controller.updateSchedule(updated)
        } else {
            let newSchedule = ScheduleRule(
                name: name,
                startTime: startTime,
                endTime: endTime,
                days: selectedDays
            )
            controller.addSchedule(newSchedule)
        }
    }
}
