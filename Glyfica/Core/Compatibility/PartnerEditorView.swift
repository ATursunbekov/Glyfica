//
//  PartnerEditorView.swift
//  Glyfica
//

import SwiftUI

struct PartnerEditorView: View {
    @EnvironmentObject private var partnerStore: PartnerStore
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var birthDate: Date
    @State private var city: String
    @State private var knowsBirthTime: Bool
    @State private var birthTime: Date

    private let isEditing: Bool

    init(existing: PartnerProfile?) {
        isEditing = existing != nil
        _name = State(initialValue: existing?.name ?? "")
        _birthDate = State(
            initialValue: existing?.birthDate
                ?? Calendar.current.date(from: DateComponents(year: 1998, month: 6, day: 15))
                ?? .now
        )
        _city = State(initialValue: existing?.city ?? "")
        _knowsBirthTime = State(initialValue: existing?.birthTime != nil)
        _birthTime = State(initialValue: existing?.birthTime ?? Date())
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NightScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(GlyficaColor.ink)
                                .frame(width: 36, height: 36)
                                .glassEffect(.regular.interactive(), in: Circle())
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(isEditing ? "Change person" : "Add someone")
                            .font(GlyficaFont.rounded(28, weight: .bold))
                            .foregroundStyle(GlyficaColor.ink)
                        Text("Enter their details, then come back to Match and run the analysis.")
                            .font(GlyficaFont.rounded(15))
                            .foregroundStyle(GlyficaColor.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    NightCard {
                        VStack(alignment: .leading, spacing: 14) {
                            fieldLabel("Their name")
                            TextField("Name", text: $name)
                                .font(GlyficaFont.rounded(17, weight: .semibold))
                                .foregroundStyle(GlyficaColor.ink)
                                .textInputAutocapitalization(.words)

                            Divider().overlay(GlyficaColor.line)

                            fieldLabel("Birth date")
                            DatePicker(
                                "Birth date",
                                selection: $birthDate,
                                in: ...Date.now,
                                displayedComponents: .date
                            )
                            .labelsHidden()
                            .colorScheme(.dark)
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Text(ZodiacSign.sunSign(for: birthDate).title)
                                .font(GlyficaFont.rounded(14, weight: .semibold))
                                .foregroundStyle(GlyficaColor.gold)

                            Divider().overlay(GlyficaColor.line)

                            Toggle(isOn: $knowsBirthTime) {
                                Text("I know their birth time")
                                    .font(GlyficaFont.rounded(15))
                                    .foregroundStyle(GlyficaColor.ink)
                            }
                            .tint(GlyficaColor.gold)

                            if knowsBirthTime {
                                DatePicker(
                                    "Birth time",
                                    selection: $birthTime,
                                    displayedComponents: .hourAndMinute
                                )
                                .labelsHidden()
                                .colorScheme(.dark)
                            }

                            Divider().overlay(GlyficaColor.line)

                            fieldLabel("City (optional)")
                            TextField("City", text: $city)
                                .font(GlyficaFont.rounded(16))
                                .foregroundStyle(GlyficaColor.ink)
                                .textInputAutocapitalization(.words)
                        }
                    }

                    GlassPrimaryButton(title: isEditing ? "Save person" : "Save & continue") {
                        save()
                    }
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.5)

                    if isEditing {
                        Button("Remove person") {
                            partnerStore.clear()
                            dismiss()
                        }
                        .font(GlyficaFont.rounded(15, weight: .semibold))
                        .foregroundStyle(GlyficaColor.danger)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(GlyficaFont.rounded(12, weight: .semibold))
            .foregroundStyle(GlyficaColor.gold)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        partnerStore.save(
            PartnerProfile(
                name: trimmed,
                birthDate: birthDate,
                birthTime: knowsBirthTime ? birthTime : nil,
                city: city.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
        dismiss()
    }
}
