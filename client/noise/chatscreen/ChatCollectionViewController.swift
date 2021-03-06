import UIKit
import RealmSwift

class ChatViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UITextFieldDelegate {
    @IBOutlet weak var CollectionView: UICollectionView!
    @IBOutlet weak var SendChatTextField: UITextField!
    @IBOutlet weak var NavigationLabel: UINavigationItem!
    @IBOutlet weak var MessageTextFieldLabel: UITextField!
    
    let realm = try! Realm()
    var friend = Friend()
    var messages = List<Message>()
    var newMessage = [String: AnyObject]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // configure states
        self.CollectionView.dataSource = self
        self.CollectionView.delegate = self
        self.title = friend.firstname
        updateChatScreen()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector (handleNewMessage), name: "newMessage", object: nil)
    }

    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.messages.count
    }
 
    func updateChatScreen() {
        if realm.objects(Conversation).filter("friendID = \(friend.friendID) ").count == 0 {
            print("-----ERROR: SEGUED TO CHAT SCREEN W/O INSTANTIATING CHAT OBJECT------")
       } else {
            self.messages = realm.objects(Conversation).filter("friendID = \(friend.friendID) ")[0].messages
            self.CollectionView.reloadData()
        }
    }

    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        // tell the controller to use the reusuable 'receivecell' controlled by chatCollectionViewCell
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("ChatCell",
            forIndexPath: indexPath) as! ChatCollectionViewCell
        
        let message = self.messages[indexPath.row]
        
        if  message.sourceID == friend.friendID {
            cell.receiveChatLabel.layer.cornerRadius = 5
            cell.receiveChatLabel.layer.masksToBounds = true
            cell.receiveChatLabel.clipsToBounds = true
            cell.receiveChatLabel.text = self.messages[indexPath.row].body
            cell.sendChatLabel.hidden = true
            return cell
        } else {
            cell.sendChatLabel.layer.cornerRadius = 5
            cell.sendChatLabel.layer.masksToBounds = true
            cell.sendChatLabel.clipsToBounds = true
            cell.sendChatLabel.text = self.messages[indexPath.row].body
            cell.receiveChatLabel.hidden = true
            return cell
        }

    }
 
    @IBAction func sendButtonTapped(sender: AnyObject) {
        self.newMessage = [
            "sourceID" : realm.objects(User)[0].userID,
            "targetID" : self.friend.friendID,
            "body"     : self.SendChatTextField.text!
        ]
        // future refactor: consider immediate persistence (w/o waiting for the server to return) to improve UX
        SocketIOManager.sharedInstance.sendEncryptedChat(newMessage)
    }
    
    @objc func handleNewMessage(notification: NSNotification) -> Void {
        
        let userInfo = notification.userInfo!
        let sourceID = userInfo["sourceID"] as? Int
        
        let message = Message()
        
        if (sourceID != nil) {
            // reciever
            if (sourceID == self.friend.friendID) {
                message.sourceID = sourceID!
                message.targetID = userInfo["targetID"] as! Int
                message.body = userInfo["body"] as! String
                message.messageID = Int((userInfo["messageID"] as! NSString).doubleValue)
                message.createdAt = userInfo["createdAt"] as! Int
            } else {
                return
            }
        } else {
            // sender
            message.sourceID = self.newMessage["sourceID"] as! Int
            message.targetID = self.newMessage["targetID"] as! Int
            message.body = self.newMessage["body"] as! String
            message.messageID = Int(userInfo["messageID"] as! String)!
            message.createdAt = userInfo["createdAt"] as! Int
        }
        
        try! realm.write{
            let conversationHistory = realm.objects(Conversation).filter("friendID = \(self.friend.friendID)")[0]
            conversationHistory.largestMessageID = message.messageID
            conversationHistory.messages.append(message)
            print("successfuly append \(message) in history", conversationHistory)
            // TODO: optimize such that only new message is loaded.
            updateChatScreen()
        }
        
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
  }

