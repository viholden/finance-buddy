import Foundation
import FirebaseFirestore

class NotificationsManager: ObservableObject {
    private let db = Firestore.firestore()
    @Published var notifications: [AppNotification] = []
    @Published var unreadCount = 0
    @Published var isLoading = false
    
    func fetchNotifications(uid: String) async throws {
        await MainActor.run { self.isLoading = true }
        
        let snapshot = try await db.collection("users").document(uid).collection("notifications")
            .order(by: "sentAt", descending: true)
            .getDocuments()
        
        let fetchedNotifications = snapshot.documents.compactMap { doc -> AppNotification? in
            try? doc.data(as: AppNotification.self)
        }
        
        await MainActor.run {
            self.notifications = fetchedNotifications
            self.unreadCount = fetchedNotifications.filter { !$0.read }.count
            self.isLoading = false
        }
    }
    
    func markAsRead(uid: String, notificationId: String) async throws {
        try await db.collection("users").document(uid).collection("notifications")
            .document(notificationId).updateData(["read": true])
        
        await MainActor.run {
            if let index = self.notifications.firstIndex(where: { $0.id == notificationId }) {
                self.notifications[index].read = true
                self.unreadCount = self.notifications.filter { !$0.read }.count
            }
        }
    }
    
    func addNotification(uid: String, notification: AppNotification) async throws {
        let docRef = db.collection("users").document(uid).collection("notifications").document(notification.id)
        try docRef.setData(from: notification)
        
        await MainActor.run {
            self.notifications.insert(notification, at: 0)
            if !notification.read {
                self.unreadCount += 1
            }
        }
    }
}
