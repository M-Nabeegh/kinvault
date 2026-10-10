import AppKit
import SwiftUI

/// Fictional specimen documents for the Rowan family of the made-up Republic of Arcadia.
///
/// They're drawn as images and imported like any scan, so the sample run exercises the real
/// pipeline: Vision OCR, Apple Intelligence extraction, and locating each value on the page.
enum SampleDocuments {
    static func makeFiles() -> [URL] {
        let folder = FileManager.default.temporaryDirectory.appending(path: "KinVault Samples", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: folder)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let specimens: [(String, AnyView)] = [
            ("Daniel passport.png", AnyView(PassportSpecimen())),
            ("Sana ID card.png", AnyView(IdentityCardSpecimen())),
            ("Ali health card.png", AnyView(InsuranceCardSpecimen())),
            ("Sana driving licence.png", AnyView(LicenceSpecimen())),
            ("Car registration.png", AnyView(VehicleSpecimen())),
            ("Electricity bill September.png", AnyView(UtilityBillSpecimen())),
        ]

        return specimens.compactMap { name, view in
            let renderer = ImageRenderer(content: view.environment(\.colorScheme, .light))
            renderer.scale = 2
            guard let image = renderer.cgImage else { return nil }
            let rep = NSBitmapImageRep(cgImage: image)
            guard let data = rep.representation(using: .png, properties: [:]) else { return nil }
            let url = folder.appending(path: name)
            return (try? data.write(to: url)) != nil ? url : nil
        }
    }
}

// MARK: - Building blocks

private let ink = Color(red: 0.10, green: 0.12, blue: 0.16)
private let faint = Color(red: 0.36, green: 0.39, blue: 0.45)

private struct Entry: View {
    let label: String
    let value: String
    var mono = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(faint)
            Text(value)
                .font(mono ? .system(size: 17, weight: .semibold, design: .monospaced) : .system(size: 17, weight: .semibold))
                .foregroundStyle(ink)
        }
    }
}

private struct SpecimenMark: View {
    var body: some View {
        Text("Specimen — fictional document for trying KinVault")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(faint.opacity(0.8))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(14)
    }
}

private struct PhotoPlaceholder: View {
    var tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(tint.opacity(0.12))
            .overlay {
                Image(systemName: "person.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(tint.opacity(0.35))
            }
    }
}

private struct Card<Content: View>: View {
    let width: CGFloat
    let height: CGFloat
    let paper: Color
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            paper
            content
            SpecimenMark()
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .padding(30)
        .background(Color.white)
    }
}

// MARK: - Specimens

private struct PassportSpecimen: View {
    let tint = Color(red: 0.13, green: 0.27, blue: 0.45)

    var body: some View {
        Card(width: 1000, height: 700, paper: Color(red: 0.95, green: 0.95, blue: 0.92)) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("REPUBLIC OF ARCADIA").font(.system(size: 22, weight: .bold)).foregroundStyle(tint)
                    Spacer()
                    Text("PASSPORT").font(.system(size: 22, weight: .bold)).foregroundStyle(tint)
                }
                .padding(.bottom, 26)
                HStack(alignment: .top, spacing: 34) {
                    PhotoPlaceholder(tint: tint).frame(width: 210, height: 270)
                    Grid(alignment: .leading, horizontalSpacing: 40, verticalSpacing: 16) {
                        GridRow {
                            Entry(label: "Type", value: "P")
                            Entry(label: "Country code", value: "ARC")
                            Entry(label: "Passport No.", value: "A0937155", mono: true)
                        }
                        GridRow {
                            Entry(label: "Surname", value: "ROWAN").gridCellColumns(3)
                        }
                        GridRow {
                            Entry(label: "Given names", value: "DANIEL JAMES").gridCellColumns(3)
                        }
                        GridRow {
                            Entry(label: "Nationality", value: "ARCADIAN")
                            Entry(label: "Sex", value: "M")
                            Entry(label: "Date of birth", value: "02 JUN 1978")
                        }
                        GridRow {
                            Entry(label: "Place of birth", value: "PORT ELLIS")
                            Entry(label: "Date of issue", value: "14 MAR 2021")
                            Entry(label: "Date of expiry", value: "14 MAR 2031")
                        }
                        GridRow {
                            Entry(label: "Authority", value: "MINISTRY OF INTERIOR").gridCellColumns(3)
                        }
                    }
                }
                Spacer()
                VStack(alignment: .leading, spacing: 6) {
                    Text("P<ARCROWAN<<DANIEL<JAMES<<<<<<<<<<<<<<<<<<<<")
                    Text("A0937155<8ARC7806021M3103145<<<<<<<<<<<<<<06")
                }
                .font(.system(size: 21, weight: .medium, design: .monospaced))
                .foregroundStyle(ink)
            }
            .padding(40)
        }
    }
}

private struct IdentityCardSpecimen: View {
    let tint = Color(red: 0.12, green: 0.42, blue: 0.36)

    var body: some View {
        Card(width: 1000, height: 630, paper: Color(red: 0.93, green: 0.96, blue: 0.94)) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ARCADIA").font(.system(size: 26, weight: .heavy)).foregroundStyle(tint)
                    Text("National Identity Card").font(.system(size: 18, weight: .medium)).foregroundStyle(tint)
                }
                .padding(.bottom, 30)
                HStack(alignment: .top, spacing: 40) {
                    VStack(alignment: .leading, spacing: 18) {
                        Entry(label: "Name", value: "Sana Rowan")
                        Entry(label: "Identity Number", value: "35202-4418820-6", mono: true)
                        HStack(spacing: 44) {
                            // Printed faintly, as on many worn cards; KinVault should ask for a check.
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Date of Birth").font(.system(size: 11, weight: .medium)).foregroundStyle(faint)
                                Text("11.09.1984")
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundStyle(ink.opacity(0.32))
                                    .blur(radius: 1.1)
                            }
                            Entry(label: "Date of Issue", value: "11.09.2017")
                            Entry(label: "Date of Expiry", value: "11.09.2027")
                        }
                        Entry(label: "Address", value: "14 Linden Row, Port Ellis")
                    }
                    Spacer()
                    PhotoPlaceholder(tint: tint).frame(width: 190, height: 240)
                }
            }
            .padding(44)
        }
    }
}

private struct InsuranceCardSpecimen: View {
    let tint = Color(red: 0.55, green: 0.18, blue: 0.20)

    var body: some View {
        Card(width: 1000, height: 600, paper: .white) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Meridian Health Insurance").font(.system(size: 28, weight: .bold)).foregroundStyle(tint)
                        Text("Member card · Family Silver plan").font(.system(size: 16)).foregroundStyle(faint)
                    }
                    Spacer()
                    Image(systemName: "cross.case.fill").font(.system(size: 44)).foregroundStyle(tint)
                }
                .padding(.bottom, 44)
                Grid(alignment: .leading, horizontalSpacing: 70, verticalSpacing: 26) {
                    GridRow {
                        Entry(label: "Member name", value: "ALI ROWAN")
                        Entry(label: "Member ID", value: "MHI-448-2190-07", mono: true)
                    }
                    GridRow {
                        Entry(label: "Group number", value: "55120", mono: true)
                        Entry(label: "Policy holder", value: "DANIEL ROWAN")
                    }
                    GridRow {
                        Entry(label: "Effective from", value: "01 DEC 2025")
                        Entry(label: "Valid until", value: "30 NOV 2026")
                    }
                }
                Spacer()
                Text("Claims and pre-approvals: 0800 555 0199 · Present this card at every visit")
                    .font(.system(size: 14)).foregroundStyle(faint)
            }
            .padding(46)
        }
    }
}

private struct LicenceSpecimen: View {
    let tint = Color(red: 0.70, green: 0.42, blue: 0.10)

    var body: some View {
        Card(width: 1000, height: 630, paper: Color(red: 0.98, green: 0.95, blue: 0.89)) {
            VStack(alignment: .leading, spacing: 0) {
                Text("ARCADIA DRIVING LICENCE").font(.system(size: 26, weight: .heavy)).foregroundStyle(tint)
                    .padding(.bottom, 30)
                HStack(alignment: .top, spacing: 40) {
                    PhotoPlaceholder(tint: tint).frame(width: 190, height: 240)
                    VStack(alignment: .leading, spacing: 18) {
                        Entry(label: "1. Surname", value: "ROWAN")
                        Entry(label: "2. Given names", value: "SANA")
                        HStack(spacing: 40) {
                            Entry(label: "3. Date of birth", value: "11/09/1984")
                            Entry(label: "Class", value: "B")
                        }
                        HStack(spacing: 40) {
                            Entry(label: "4a. Issued", value: "21/08/2016")
                            Entry(label: "4b. Expiry", value: "21/08/2026")
                        }
                        Entry(label: "5. Licence No.", value: "DL-77310-RW", mono: true)
                    }
                }
            }
            .padding(44)
        }
    }
}

private struct VehicleSpecimen: View {
    let tint = Color(red: 0.20, green: 0.22, blue: 0.28)

    var body: some View {
        Card(width: 1000, height: 720, paper: .white) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Port Ellis Transport Authority").font(.system(size: 16, weight: .medium)).foregroundStyle(faint)
                Text("Vehicle Registration Certificate").font(.system(size: 30, weight: .bold)).foregroundStyle(tint)
                    .padding(.bottom, 34)
                Grid(alignment: .leading, horizontalSpacing: 70, verticalSpacing: 24) {
                    GridRow {
                        Entry(label: "Registered owner", value: "Daniel Rowan")
                        Entry(label: "Registration No.", value: "PEX-2291", mono: true)
                    }
                    GridRow {
                        Entry(label: "Make and model", value: "Toyota Corolla 1.6")
                        Entry(label: "Colour", value: "Silver")
                    }
                    GridRow {
                        Entry(label: "Chassis No.", value: "JT2AE09W5P0012345", mono: true)
                        Entry(label: "Engine No.", value: "4ZZ-8841207", mono: true)
                    }
                    GridRow {
                        Entry(label: "Date of registration", value: "31 January 2024")
                        Entry(label: "Valid until", value: "31 January 2027")
                    }
                    GridRow {
                        Entry(label: "Address", value: "14 Linden Row, Port Ellis").gridCellColumns(2)
                    }
                }
            }
            .padding(46)
        }
    }
}

private struct UtilityBillSpecimen: View {
    let tint = Color(red: 0.10, green: 0.36, blue: 0.62)

    var body: some View {
        Card(width: 860, height: 1100, paper: .white) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Port Ellis Electric Company").font(.system(size: 28, weight: .bold)).foregroundStyle(tint)
                        Text("Electricity bill").font(.system(size: 18)).foregroundStyle(faint)
                    }
                    Spacer()
                    Image(systemName: "bolt.fill").font(.system(size: 40)).foregroundStyle(tint)
                }
                .padding(.bottom, 44)

                Grid(alignment: .leading, horizontalSpacing: 60, verticalSpacing: 22) {
                    GridRow {
                        Entry(label: "Account name", value: "The Rowan Family")
                        Entry(label: "Account No.", value: "0045-778120", mono: true)
                    }
                    GridRow {
                        Entry(label: "Supply address", value: "14 Linden Row, Port Ellis").gridCellColumns(2)
                    }
                    GridRow {
                        Entry(label: "Billing period", value: "01 Sep 2026 – 30 Sep 2026")
                        Entry(label: "Units used", value: "412 kWh")
                    }
                }
                .padding(.bottom, 44)

                VStack(spacing: 0) {
                    BillLine(item: "Energy charge (412 kWh)", amount: "12,360.00")
                    BillLine(item: "Fixed service charge", amount: "950.00")
                    BillLine(item: "Electricity duty", amount: "1,510.00")
                    BillLine(item: "Amount due", amount: "14,820.00", bold: true)
                }
                .padding(.bottom, 40)

                HStack(spacing: 60) {
                    Entry(label: "Due date", value: "24 Oct 2026")
                    Entry(label: "Late payment after due date", value: "15,560.00")
                }
                Spacer()
                Text("Pay online, at any bank branch, or by standing order. Keep this bill for your records.")
                    .font(.system(size: 14)).foregroundStyle(faint)
            }
            .padding(54)
        }
    }
}

private struct BillLine: View {
    let item: String
    let amount: String
    var bold = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(item)
                Spacer()
                Text(amount).monospacedDigit()
            }
            .font(.system(size: 17, weight: bold ? .bold : .regular))
            .foregroundStyle(ink)
            .padding(.vertical, 12)
            Rectangle().fill(faint.opacity(0.25)).frame(height: 1)
        }
    }
}
