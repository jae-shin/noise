import UIKit
import RealmSwift

class LoginViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    
    let realm = try! Realm()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Override username and password events
        usernameTextField.delegate = self;
        passwordTextField.delegate = self;
        
        // Attach listeners
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: #selector(computeBob),
            name: "computeBob",
            object: nil)

    }

    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        self.view.endEditing(true);
        
        // Hide keyboard if user taps outside of the input field
        super.touchesBegan(touches, withEvent:event)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        if textField == usernameTextField {
            passwordTextField.becomeFirstResponder()
        } else if textField == passwordTextField {
            textField.resignFirstResponder()
            
            // Attach listeners
            NSNotificationCenter.defaultCenter().addObserver(
                self,
                selector: #selector(handleSignInNotification),
                name: "signin",
                object: nil)

            // Log in
            let userName = usernameTextField.text
            let userPassword = passwordTextField.text
            let user: [String: String] = [
                "username": userName!,
                "password": userPassword!
            ]

            SocketIOManager.sharedInstance.signIn(user)
        }
        
        return true
    }
    
    @objc func handleSignInNotification(notification: NSNotification) -> Void {
        
        if let signInObj = notification.userInfo {
            
            let userObj = signInObj["user"]
            
            // insert user data in realm
            let user = User()
            user.firstname = userObj!["firstname"] as! String
            user.lastname = userObj!["lastname"] as! String
            user.username = userObj!["username"] as! String
            user.userID = Int(userObj!["userID"] as! String)!
            user.id = 0
            
            try! realm.write {
                realm.add(user, update:true)
            }
            var dhxObj : [String:AnyObject] = [:]
            dhxObj["userID"] = user.userID
            dhxObj["username"] = user.username
            //what else?!
            
            SocketIOManager.sharedInstance.checkForPendingKeyExchange(dhxObj)
            performSegueWithIdentifier("loginToFriendsListSegue", sender: self)
            
        } else {
            let alert:UIAlertController = UIAlertController(title: "Ooftah!", message: "username or password is incorrect", preferredStyle: UIAlertControllerStyle.Alert)
            let action:UIAlertAction = UIAlertAction(title: "okee", style: UIAlertActionStyle.Default) { (a: UIAlertAction) -> Void in
                print("okee button selected")
            }
            alert.addAction(action)
            self.presentViewController(alert, animated:true) { () -> Void in
                print("alert presented for unsuccessful login")
            }
        }
        
        // Remove listener
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    @objc func computeBob(notification:NSNotification) -> Void {
        let dhxInfo = notification.userInfo
        print("dhx info inside of compute bob [LOGIN] is \(dhxInfo)!")

        let Bob = 666.bobify(dhxInfo!["userID"]!, friendID: dhxInfo!["friendID"]!, E_Alice: dhxInfo!["eAlice"]!, p: dhxInfo!["pAlice"]!, g: dhxInfo!["gAlice"]!)
        
        //NSNotificationCenter.defaultCenter().removeObserver(self)
        SocketIOManager.sharedInstance.commencePart2KeyExchange(Bob)

        //TODO: pass computed value directly into
        //1) keychain
        //2) encryption
        //3)
    }
    
    @IBAction func signUpButtonClicked(sender: AnyObject) {
        self.performSegueWithIdentifier("signUpSegue", sender: self)
    }
    
}
