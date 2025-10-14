import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var notificationsManager = NotificationsManager()
    
    var body: some View {
        ZStack {
            if notificationsManager.isLoading {
                ProgressView()
            } else if notificationsManager.notifications.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("No Notifications")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("You're all caught up!")
                        .foregroundColor(.secondary)
                }
            } else {
                List {
                    ForEach(notificationsManager.notifications) { notification in
                        NotificationRowView(notification: notification, notificationsManager: notificationsManager)
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .task {
            if let uid = authManager.user?.uid {
                try? await notificationsManager.fetchNotifications(uid: uid)
            }
        }
    }
}

struct NotificationRowView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    let notification: AppNotification
    @ObservedObject var notificationsManager: NotificationsManager
    
    var iconName: String {
        switch notification.type {
        case "goalReminder": return "target"
        case "challengeUpdate": return "trophy"
        case "lessonComplete": return "book"
        case "expenseAlert": return "exclamationmark.triangle"
        default: return "bell"
        }
    }
    
    var iconColor: Color {
        switch notification.type {
        case "goalReminder": return .blue
        case "challengeUpdate": return .orange
        case "lessonComplete": return .green
        case "expenseAlert": return .red
        default: return .gray
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: iconName)
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.message)
                    .font(notification.read ? .body : .body.weight(.semibold))
                
                Text(notification.sentAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !notification.read {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            markAsRead()
        }
    }
    
    private func markAsRead() {
        guard let uid = authManager.user?.uid, !notification.read else { return }
        
        Task {
            try? await notificationsManager.markAsRead(uid: uid, notificationId: notification.id)
        }
    }
}
