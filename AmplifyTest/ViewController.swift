//
//  ViewController.swift
//  AmplifyTest
//
//  Created by Li, Sida on 26/3/19.
//  Copyright © 2019 Sida Li. All rights reserved.
//

import UIKit

import AWSAppSync
import AWSMobileClient
import AWSPinpoint

import AWSCognitoIdentityProvider

class ViewController: UIViewController {
    @IBOutlet weak var buttonAddTodoItem: UIBarButtonItem!
    @IBOutlet weak var buttonUserManagement: UIBarButtonItem!
    
    @IBOutlet weak var tableView: UITableView!
    lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action:
            #selector(ViewController.handleRefresh(_:)),
                                 for: UIControl.Event.valueChanged)
        refreshControl.tintColor = UIColor.red
        
        return refreshControl
    }()
    @objc func handleRefresh(_ refreshControl: UIRefreshControl) {
        self.runQuery()
    }
    
    var tableViewDataSourceArray: [ListTodosQuery.Data.ListTodo.Item?]?
    
    //Reference AppSync client
    var appSyncClient: AWSAppSyncClient?
    var pinpoint: AWSPinpoint?
    var discard: Cancellable?

    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        self.tableView.addSubview(self.refreshControl)
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appSyncClient = appDelegate.appSyncClient
        pinpoint = appDelegate.pinpoint
        
        //test app sync here
//        subscribe()
        
        AWSMobileClient.sharedInstance().addUserStateListener(self) { (userState, info) in
            
            print("--- Get user state notification userState:\(userState) info:\(info)")
            
            switch (userState) {
            case .signedIn:
                self.sendUserAuthEvent(userState: "_userauth.sign_in")
                
                AWSMobileClient.sharedInstance().getTokens { (tokens, error) in
                    if let error = error {
                        print("--- getTokens error:\(error)")
                    }

                    if let tokens = tokens {
                        let email = tokens.idToken?.claims?["email"] as? String

                        DispatchQueue.main.async {
                            self.navigationItem.title = email
                            
                            self.buttonUserManagement.title = "SignOut"

                            self.refreshControl.beginRefreshingManually()
                            
                            self.subscribe()
                            
                            
                        }
                    }
                }
            case .signedOut:
                self.sendUserAuthEvent(userState: "_userauth.sign_out")
                
                self.unsubscribe()
                
                DispatchQueue.main.async {
                    self.navigationItem.title = ""
                    self.buttonUserManagement.title = "SignIn"
                }
            default:
                break
            }
        }
        
        userSignOut()
        
    }
    
    // MARK: IBActions
    @IBAction func onTapAddItem(_ sender: Any) {
        //TODO: check user state
        
        let alert = UIAlertController(title: "Add To-do Item", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel action"), style: .cancel, handler: { _ in
            print("The \"Cancel\" alert occured.")
        }))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Add", comment: "Add action"), style: .default, handler: { _ in
            print("The \"Add\" alert occured.")
            var name: String = "", description: String = ""
            
            alert.textFields?.forEach { textfield in
                switch textfield.tag {
                case 0:
                    name = textfield.text ?? "default name"
                case 1:
                    description = textfield.text == "" ? "default description" : textfield.text!
                default:
                    break
                }
            }
            
            print("new to-do item with name - " + name + " and description - " + description + " will be added")
            
            self.runAddNewTodoItem(with: name, description: description)
        }))
        alert.addTextField { textfield in
            textfield.tag = 0
            textfield.placeholder = "item name"
        }
        alert.addTextField { textfield in
            textfield.tag = 1
            textfield.placeholder = "item description"
            
        }
        
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func onTapUserManagement(_ sender: Any) {
        if (AWSMobileClient.sharedInstance().currentUserState == .signedIn) {
            userSignOut()
        } else {
            // TODO: toggle between drop-in Auth UI and programatically sign in
//            showDropInAuthUI()
            signIn()
        }
    }
    
    
    @IBAction func onTapUnsub(_ sender: Any) {
        
        self.unsubscribe()
        
    }
    
    func showDropInAuthUI() {
        AWSMobileClient.sharedInstance().showSignIn(navigationController: self.navigationController!,
                                                    signInUIOptions: SignInUIOptions(canCancel: true)) { (userState, error) in
            if let error = error {
                print("in drop-in auth, error " + error.localizedDescription)
            }
        }
    }
    
    func userSignOut() {
        AWSMobileClient.sharedInstance().signOut(options: SignOutOptions(signOutGlobally: false, invalidateTokens: true)) { error in
            if let error = error {
                print("sign out error " + error.localizedDescription)
            }
        }
    }
    
    // sign in user programatically
    func signIn(user: String = "lsida@amazon.com", password: String = "123223") {
        AWSMobileClient.sharedInstance().signIn(username: user, password: password) { (signInResult, error) in
            if let error = error  {
                print("in signIn(), error:\(error)")
            } else if let signInResult = signInResult {
                print("in signIn(), signInResult:\(signInResult)")
                
                switch (signInResult.signInState) {
                case .signedIn:
                    print("User with username \(user) is signed in.")
                case .smsMFA:
                    print("SMS message sent to \(signInResult.codeDetails!.destination!)")
                default:
                    print("Sign In needs info which is not et supported.")
                }
            }
        }
    }
    
    // MARK: AppSync
    
    func subscribe() {
        do {
            discard = try appSyncClient?.subscribe(subscription: OnChangeTodoSubscription(), resultHandler: { (result, transaction, error) in
                if let result = result {
                    print("in create sub callback " + result.data!.onChangeTodo!.name + " " + result.data!.onChangeTodo!.description!)
                    
                    self.runQuery()
                } else if let error = error {
                    print("in create sub callback, error:\(error.localizedDescription)")
                }
            })
        } catch {
            print("Error starting subscription.")
        }
    }
    
    func unsubscribe() {
        if let discard = discard {
            discard.cancel()
            print("unsubsribe from AppSync")
        }
    }
    
    func runMutation(){
        let mutationInput = CreateTodoInput(owner: AWSMobileClient.sharedInstance().username!, name: "Use AppSync", description:"Realtime and Offline")
        appSyncClient?.perform(mutation: CreateTodoMutation(input: mutationInput)) { (result, error) in
            if let error = error as? AWSAppSyncClientError {
                print("Error occurred: \(error.localizedDescription )")
            }
            if let resultError = result?.errors {
                print("Error saving the item on server: \(resultError)")
                return
            }
        }
    }
    
    func runQuery(){
        appSyncClient?.fetch(query: ListTodosQuery(filter: ModelTodoFilterInput(owner: ModelIDFilterInput(contains: AWSMobileClient.sharedInstance().username!))), cachePolicy: .fetchIgnoringCacheData) {(result, error) in
            if error != nil {
                print(error?.localizedDescription ?? "")
                return
            }
            
            result?.data?.listTodos?.items!.forEach { print("in runQuery() " + ($0?.name)! + " " + ($0?.description)!) }
            
            if let items = result?.data?.listTodos?.items {
                self.tableViewDataSourceArray = items
                DispatchQueue.main.async {
                    self.refreshControl.endRefreshing()
                    self.tableView.reloadData()
                }
            }
        }
    }
    
    func runRemove(id: GraphQLID) {
        let mutationInput = DeleteTodoInput(id: id)
        appSyncClient?.perform(mutation: DeleteTodoMutation(input: mutationInput)) { (result, error) in
            if let error = error as? AWSAppSyncClientError {
                print("Error occurred: \(error.localizedDescription )")
            }
            if let resultError = result?.errors {
                print("Error saving the item on server: \(resultError)")
                return
            }
        }
    }
    
    func runAddNewTodoItem(with name: String, description: String) {
        let mutationInput = CreateTodoInput(owner: AWSMobileClient.sharedInstance().username!, name: name, description: description)
        appSyncClient?.perform(mutation: CreateTodoMutation(input: mutationInput)) { (result, error) in
            if let error = error as? AWSAppSyncClientError {
                print("Error occurred: \(error.localizedDescription )")
            }
            if let resultError = result?.errors {
                print("Error saving the item on server: \(resultError)")
                return
            }
        }
    }
    
    
    // MARK: Pinpoint Analytics
    
//    func logScreenEvent(name screenName: String) {
//        if let analyticsClient = pinpoint?.analyticsClient {
//            let event = analyticsClient.createEvent(withEventType: "ScreenEvent")
//            event.addAttribute(screenName, forKey: "Name")
//            event.addMetric(NSNumber(value: arc4random() % 65535), forKey: "EventName")
//            analyticsClient.record(event)
//            analyticsClient.submitEvents()
//        }
//    }
    
    func sendUserAuthEvent(userState: String) {
        if let analyticsClient = pinpoint?.analyticsClient {
            let event = analyticsClient.createEvent(withEventType: userState)
            analyticsClient.record(event)
            analyticsClient.submitEvents()
        }
    }
    
//    func sendMonetizationEvent() {
//        if let analyticsClient = pinpoint?.analyticsClient {
//            let event = analyticsClient.createVirtualMonetizationEvent(
//                withProductId: "DEMO_PRODUCT_ID",
//                withItemPrice: 1.00,
//                withQuantity: 1,
//                withCurrency: "USD"
//            )
//            analyticsClient.record(event)
//            analyticsClient.submitEvents()
//        }
//    }
}

extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let count = self.tableViewDataSourceArray?.count else {
            return 0
        }
        
        return count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "todoCell", for: indexPath)
        guard let sourceArray = self.tableViewDataSourceArray else {
            return cell
        }
        
        cell.textLabel!.text = sourceArray[indexPath.row]?.name
        
        return cell
    }
    
    
}

extension ViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        switch editingStyle {
        case .delete:
                if let dataSourceArry = tableViewDataSourceArray, let item = dataSourceArry[indexPath.row] {
                    runRemove(id: item.id)
                    tableViewDataSourceArray!.remove(at: indexPath.row)
                }
                //TODO: may need tableview start update / stop update here if also subscribe to changes
                tableView.deleteRows(at: [indexPath], with: .fade)
        default:
            break
        }
    }
}

extension UIRefreshControl {
    
    func beginRefreshingManually() {
        if let scrollView = superview as? UIScrollView {
            scrollView.setContentOffset(CGPoint(x: 0, y: scrollView.contentOffset.y - frame.height), animated: false)
        }
        beginRefreshing()
        sendActions(for: .valueChanged)
    }
    
}
