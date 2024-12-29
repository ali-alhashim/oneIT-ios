//
//  TimesheetView.swift
//  oneIT
//
//  Created by ALI MUSA ALHASHIM on 25-12-2024.
//
import SwiftUI


struct TimesheetData: Decodable, Identifiable {
    let id = UUID()
    let dayDate: String
    let checkIn: String
    let checkOut: String
    let totalMinutes: String
    
    enum CodingKeys: String, CodingKey {
        case dayDate
        case checkIn
        case checkOut
        case totalMinutes
    }
}
  


// MARK: - Timesheet View
struct TimesheetView: View {
    let timesheetData: [TimesheetData]
   
    var body: some View {
        NavigationView {
            
            List(timesheetData) { entry in
                VStack(alignment: .leading, spacing: 8) {
                    Text(formatDate(entry.dayDate))
                        .font(.headline)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Check In:")
                                .foregroundColor(.secondary)
                            Text(formatTime(entry.checkIn))
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading) {
                            Text("Check Out:")
                                .foregroundColor(.secondary)
                            Text(formatTime(entry.checkOut))
                        }
                    }
                    
                    Text("Duration: \(formatDuration(minutes: entry.totalMinutes))")
                        .foregroundColor(.blue)
                }
                .padding(.vertical, 8)
            }
            
            .navigationBarTitle("Timesheet")
           
            
        }
    }
    
    // MARK: - Formatting Helpers
    
    private func formatDate(_ dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "EEEE, MMM d"
        
        if let date = inputFormatter.date(from: dateString) {
            return outputFormatter.string(from: date)
        }
        return dateString
    }
    
    private func formatTime(_ timeString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "HH:mm:ss.SSS"
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "h:mm a"
        
        if let date = inputFormatter.date(from: timeString) {
            return outputFormatter.string(from: date)
        }
        return timeString
    }
    
    private func formatDuration(minutes: String) -> String {
        guard let mins = Int(minutes) else { return "Invalid duration" }
        let hours = mins / 60
        let remainingMinutes = mins % 60
        return "\(hours)h \(remainingMinutes)m"
    }
}
