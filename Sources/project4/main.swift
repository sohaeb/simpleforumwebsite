import CouchDB
import Cryptor
import Foundation
import HeliumLogger
import Kitura
import KituraNet
import KituraSession
import KituraStencil
import LoggerAPI
import Stencil
import SwiftyJSON

func send(error: String, code: HTTPStatusCode, to response: RouterResponse) {
    _ = try? response.status(code).send(error).end()
}

func context(for request: RouterRequest) -> [String: Any] {
    var result = [String: String]()
    result["username"] = request.session?["username"].string
    
    return result
}

func password(from str: String, salt: String) -> String {
    let key = PBKDF.deriveKey(fromPassword: str, salt: salt, prf: .sha512, rounds: 250_000, derivedKeyLength: 64)
    return CryptoUtils.hexString(from: key)
}

extension String {
    func removingHTMLEncoding() -> String {
        let result = self.replacingOccurrences(of: "+", with: " ")
        return result.removingPercentEncoding ?? result
    }
}

// Function to get detauls from request
func getPost(for request: RouterRequest, fields: [String]) -> [String: String]? {
    guard let values = request.body else { return nil }
    guard case .urlEncoded(let body) = values else { return nil }
    
    var result = [String: String]()
    
    for field in fields {
        if let value = body[field]?.trimmingCharacters(in: .whitespacesAndNewlines) {
            if value.count > 0 {
                result[field] = value.removingHTMLEncoding()
                continue
            }
        }
        
        return nil
    }
    
    return result
}

HeliumLogger.use()
//------------------------------------------------------------------------------------//

let connectionProperties = ConnectionProperties(host: "localhost", port: 5984, secured: false)
let client = CouchDBClient(connectionProperties: connectionProperties)
let database = client.database("forum")

let router = Router()

//------------------------------------------------------------------------------------//


// Kitura Class
let ext = Extension()

// Create a new Filter
ext.registerFilter("format_date") { (value: Any?) in
    if let value = value as? String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        
        if let date = formatter.date(from: value) {
            formatter.dateStyle = .long
            formatter.timeStyle = .medium
            return formatter.string(from: date)
        }
    }
    
    return value
}

//ext.registerFilter("user_same") { (value: Any?) in
//
//    if let value = value as? String {
//
//        guard let username = request.session?["username"].string else {
//
//
//            return true
//        }
//
//        if value == "soso" {
//    }
//
//    return false
//}



router.setDefault(templateEngine: StencilTemplateEngine(extension: ext))
router.post("/", middleware: BodyParser())
router.all("/static", middleware: StaticFileServer())


// Secret
router.all(middleware: Session(secret: "The rain in Spain falls mainly on the Spaniards"))

//------------------------------------------------------------------------------------//
//-----------------------------        \        --------------------------------------//
//------------------------------------------------------------------------------------//

// MARK:- /
router.get("/") {
    request, response, next in
    
    database.queryByView("forums", ofDesign: "forum", usingParameters: []) { forums, error in
        
        defer { next() }
        
        if let error = error {
            send(error: error.localizedDescription, code: .internalServerError, to: response)
            
        } else if let forums = forums {
            var forumContext = context(for: request)
            forumContext["forums"] = forums["rows"].arrayObject
            
            _ = try? response.render("home-copy", context: forumContext)
        }
    }
}


//------------------------------------------------------------------------------------//
//-----------------------------       /delete        --------------------------------------//
//------------------------------------------------------------------------------------//


router.post("/delete/:revID/:id") {
    request, response, next in
    //    print("we reached here1")
    //    guard let msgID = request.parameters["id"] else {
    //        try response.status(.badRequest).end()
    //        return
    //    }
    //
    //    print("we reached here2")
    //    guard let revID = request.parameters["revID"] else {
    //        try response.status(.badRequest).end()
    //        return
    //    }
    //
    //    print("we reached here3")
    //
    //    print("we reached here4")
    //    // 3-
    //
    //    print("we reached here5")
    
}


//------------------------------------------------------------------------------------//
//---------------------------     /home      -----------------------------------------//
//------------------------------------------------------------------------------------//
//MARK:- /home

router.get("/home") {
    request, response, next in
    
    guard let username = request.session?["username"].string else {
    
        _ = try? response.redirect("/login")
        return
    }
    
    database.retrieve(username) { doc, error in
        if error == nil {
            // username exists
            
            // Check if he's admin
            if doc!["admin"] == "yes"{
                
                // Get all msges sent to us from Contact us
                database.queryByView("forums", ofDesign: "forum", usingParameters: []) { forums, error in
                    defer { next() }
                    
                    if let error = error {
                        send(error: error.localizedDescription, code: .internalServerError, to: response)
                        
                    } else if let forums = forums {
                        
                        //typical stuff to render msgs to HTML
                        var forumContext = context(for: request)
                        forumContext["forums"] = forums["rows"].arrayObject
                        
                        // send it to an alternative home page HTML
                        _ = try? response.render("home_admin", context: forumContext)
                    }
                }
            }
            
        } else {
            print("error inside /home DB")
        }
    }
    
    database.queryByView("forums", ofDesign: "forum", usingParameters: []) { forums, error in
        defer { next() }
        
        if let error = error {
            send(error: error.localizedDescription, code: .internalServerError, to: response)
        } else if let forums = forums {
            var forumContext = context(for: request)
            forumContext["forums"] = forums["rows"].arrayObject
            
            _ = try? response.render("home", context: forumContext)
        }
    }
}

//------------------------------------------------------------------------------------//
//---------------------------     /admin      -----------------------------------------//
//------------------------------------------------------------------------------------//
// MARK:- Get ---> Admin

router.get("/admin") {
    request, response, next in
    
    print("here")
    
    // check if user is logged in
    guard let username = request.session?["username"].string else {
        //         try response.render("users-login", context: [:])
        _ = try? response.redirect("/login")
        return
    }
    print("here2")
    // retreive user's data based on his name
    database.retrieve(username) { doc, error in
        if error == nil {
            
            if doc!["admin"] == "yes" {
                
                database.queryByView("users", ofDesign: "forum", usingParameters: [])
                { forums, error in
                    defer { next() }
                    
                    if let error = error {
                        send(error: error.localizedDescription, code: .internalServerError, to: response)
                        
                        // Retrieve all msgs inside a forum
                    } else if let forums = forums {
                        
                        var forumContext = context(for: request)
                        forumContext["forums"] = forums["rows"].arrayObject
                        
                        _ = try? response.render("admin", context: forumContext)
                    }
                }
            } else {
                
                print("outside admin")
                _ = try? response.redirect("/home")
                
            }
        }
    }
}

// MARK: POST ---> /admin

router.post("/admin") {
    request, response, next in
    
    // check logged in
    guard let username = request.session?["username"].string else {
        send(error: "You are not logged in", code: .forbidden, to: response)
        return
    }
    
    // get values
    guard let fields = getPost(for: request, fields: ["name"]) else {
        send(error: "Missing required fields", code: .badRequest, to: response)
        return
    }
    
    //    if fields["name"]! == username {
    //        send(error: "cannot delete your logged in account", code: .badRequest, to: response)
    //
    //        return
    //    }
    
    
    // 1st msg
    database.retrieve(fields["name"]!) { doc, error in
        print("name is ")
        print(fields["name"]!)
        defer { next() }
        
        if error != nil {
            send(error: "Unable to load user's name from DB.", code: .badRequest, to: response)
            
            // 3- Username is loaded/exists
        } else if let doc = doc {
            print("doc si")
            print(doc)
            print("here5")
            database.queryByView("forum_posts", ofDesign: "forum", usingParameters: [.keys([doc as Database.KeyType])]) { replies, error in
                defer { next() }
                
                if let error = error {
                    send(error: error.localizedDescription, code: .internalServerError, to: response)
                    
                    // 6-
                } else if let replies = replies {
                    print("here6")
                    
                    
                    var pageContext = context(for: request)
                    //
                    pageContext["replies"] = replies["rows"].arrayObject
                    //
                    _ = try? response.render("admin_search", context: pageContext)
                }
            }
            
            // end
        }
    }
}

//------------------------------------------------------------------------------------//
//---------------------------     /admin/reply      -----------------------------------------//
//------------------------------------------------------------------------------------//
// MARK:- Get ---> /admin/reply

router.get("/admin/reply") {
    request, response, next in
    database.queryByView("contact_us", ofDesign: "forum", usingParameters: [])
    { forums, error in
        defer { next() }
        
        if let error = error {
            send(error: error.localizedDescription, code: .internalServerError, to: response)
            
            // Retrieve all msgs inside a forum
        } else if let forums = forums {
            var forumContext = context(for: request)
            forumContext["forums"] = forums["rows"].arrayObject
            
            _ = try? response.render("admin-reply", context: forumContext)
        }
    }
}




//------------------------------------------------------------------------------------//
//---------------------------     /contactus      -----------------------------------------//
//------------------------------------------------------------------------------------//

// MARK:- GET ---> Contact Us

router.get("/contact") {
    request, response, next in
    
    defer { next() }
    
    try response.render("contact-us", context: [:])
    
}
// MARK: POST ---> Contact Us
router.post("/contact") {
    request, response, next in
    
    guard let username = request.session?["username"].string else {
        send(error: "You are not logged in", code: .forbidden, to: response)
        return
    }
    
    guard let fields = getPost(for: request, fields: ["body"]) else {
        send(error: "Missing required fields", code: .badRequest, to: response)
        return
    }
    
    database.retrieve(username) { doc, error in
        
        defer { next() }
        
        if error != nil {
            send(error: "Unable to load user.", code: .badRequest, to: response)
            
            // 3- User is loaded/exists
        } else if let doc = doc {
            
            // 4-
            // load the salt and password from docs
            
            var newMessage = [String: String]()
            
            // 4-
            newMessage["body"] = fields["body"]!
            print("Test1")
            print(fields["body"]!)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            newMessage["date"] = formatter.string(from: Date())
            
            newMessage["name"] =  username
            print("Test2")
            
            newMessage["email"] = doc["email"].stringValue
            newMessage["type"] = "contact_message"
            newMessage["user"] = username
            
            let newMessageJSON = JSON(newMessage)
            
            // 5-
            database.create(newMessageJSON) { id, revision, doc, error in
                defer { next() }
                
                if error != nil {
                    send(error: "msg could not be created", code: .internalServerError, to: response)
                } else {
                    print("Created")
                    _ = try? response.redirect("/contact")
                    
                }
            }
        }
    }
}

//------------------------------------------------------------------------------------//
//---------------------------     /search      -----------------------------------------//
//------------------------------------------------------------------------------------//

// MARK: - Search (GET)

router.get("/search") {
    request, response, next in
    defer { next() }
    
    try response.render("search", context: [:])
}

// MARK: Search (POST)

router.post("/search") {
    request, response, next in
    
    defer { next() }
    
    // get values
    guard let fields = getPost(for: request, fields: ["name"]) else {
        send(error: "Missing required fields", code: .badRequest, to: response)
        return
    }
    
    database.queryByView("comment", ofDesign: "forum", usingParameters: []) { replies, error in
        
        if let error = error {
            send(error: error.localizedDescription, code: .internalServerError, to: response)
            
            // 6-
        } else if let replies = replies {
            
            let arrayOfStuff = replies["rows"]
            
            print(replies["rows"].arrayObject)
            
            var searchArray = [String:String]()
            var searchArrayDictionary = [[String:String]]()
            
            var pageContext = context(for: request)
            
            for (_,subJson):(String, JSON)  in arrayOfStuff {
                
                let word = subJson["value"]["body"].stringValue
                
                if  word.contains(fields["name"]!) {
                    print("Word found is \(fields["name"]!) in \(word)")
                    print("id is \(subJson["id"].stringValue)")
                    print("body is \(subJson["value"]["body"].stringValue)")
                    searchArray["id"] = subJson["id"].stringValue
                    searchArray["body"] = subJson["value"]["body"].stringValue
                    searchArray["forum"] = subJson["value"]["forum"].stringValue
                    print(subJson["value"]["forum"].stringValue)
                    
                    searchArrayDictionary.append(searchArray)
                }
                
            }
            
            print(searchArrayDictionary)
            
            let newMessageJSON = JSON(searchArrayDictionary)
            
            pageContext["replies"] = newMessageJSON.arrayObject
            
            //            print(newMessageJSON.arrayObject)
            
            _ = try? response.render("search", context: pageContext)
            
            // end
        }
    }
}

//------------------------------------------------------------------------------------//
//--------------------------     /forum/:forumid     ----------------------------//
//------------------------------------------------------------------------------------//

// MARK:- GET --> List of topics inside forum/fourmid

router.get("/forum/:forumid") {
    request, response, next in
    
    // Grab the name of the forum from the URL
    guard let forumID = request.parameters["forumid"] else {
        send(error: "Missing forum ID", code: .badRequest, to: response)
        return
    }
    
    // Get all the docs that is related to the name_forum
    database.retrieve(forumID) { forum, error in
        
        if let error = error {
            send(error: error.localizedDescription, code: .notFound, to: response)
        }
            
            // if forum name exists
        else if let forum = forum {
            
            // Retrieve all Topics inside a forum
            database.queryByView("forum_posts", ofDesign: "forum", usingParameters: [.keys([forumID as Database.KeyType]), .descending(true)]) { topics, error in
                defer { next() }
                
                if let error = error {
                    send(error: error.localizedDescription, code: .internalServerError, to: response)
                    
                    // Retrieve all msgs inside a forum
                } else if let topics = topics {
                    var pageContext = context(for: request)
                    pageContext["forum_id"] = forum["_id"].stringValue
                    pageContext["forum_name"] = forum["name"].stringValue
                    pageContext["topics"] = topics["rows"].arrayObject
                    
                    _ = try? response.render("forum", context: pageContext)
                }
            }
        }
    }
}


//-----------------------

// MARK:- /delete/:revID/:id
router.get("/delete/:revID/:id/:forumid/:topicID") {
    
    request, response, next in
    
    //    guard let username = request.session?["username"].string else {
    //        //         try response.render("users-login", context: [:])
    //        _ = try? response.redirect("/login")
    //        return
    //    }
    
    guard let revID = request.parameters["revID"],
        let msgID = request.parameters["id"],
        let forumID = request.parameters["forumid"],
     let topicID = request.parameters["topicID"] else {
            try response.status(.badRequest).end()
            return
    }
    print("here1")
    database.delete(msgID, rev: revID, callback: { (error) in
        if error != nil {
            send(error: "msg could not be created", code: .internalServerError, to: response)
        } else {
            //                  _ = try? response.render("home", context: forumContext)
            print("here2")
            response.send("comment deleted")

            _ = try? response.redirect("/forum/\(forumID)/\(topicID)")


        }
    })
}



//------------------------------------------------------------------------------------//
//--------------------     /forum/:forumid/:messageid"   ------------------------------//
//------------------------------------------------------------------------------------//

// MARK:- GET --> List of replies inside topic /forum/forumid/topics

// 1- Get parameters from URL
// 2- Retrieve from forumID
// 3- Retrieve from messageID
// 4- check if topic is already in DB i.e: Created
// 5- retrieve all replies using topicID/msgID
// 6- if replies exists, send them as array of JSON to stencil

router.get("/forum/:forumid/:messageid") {
    request, response, next in
    
    // 1-
    guard let forumID = request.parameters["forumid"],
        let topicID = request.parameters["messageid"] else {
            try response.status(.badRequest).end()
            return
    }
    
    guard let username = request.session?["username"].string else {
        send(error: "You are not logged in", code: .forbidden, to: response)
        return
    }
    
    // 2-
    database.retrieve(forumID) { forum, error in
        
        if let error = error {
            send(error: error.localizedDescription, code: .notFound, to: response)
            
        } else if let forum = forum {
            
            // 3-
            database.retrieve(topicID) { topic, error in
                if let error = error {
                    send(error: error.localizedDescription, code: .notFound, to: response)
                    
                    // 4- if topic/msg found
                } else if let topic = topic {
                    
                    // 5-
                    database.queryByView("forum_replies", ofDesign: "forum", usingParameters: [.keys([topicID as Database.KeyType])]) { replies, error in
                        defer { next() }
                        
                        if let error = error {
                            send(error: error.localizedDescription, code: .internalServerError, to: response)
                            
                            // 6-
                        } else if let replies = replies {
                            var pageContext = context(for: request)
                            pageContext["username"] = username
                            pageContext["forum_id"] = forum["_id"].stringValue
                            pageContext["forum_name"] = forum["name"].stringValue
                            pageContext["topic"] = topic.dictionaryObject!
                            pageContext["replies"] = replies["rows"].arrayObject
                            
                            _ = try? response.render("message", context: pageContext)
                        }
                    }
                }
            }
        }
    }
}

//------------------------------------------------------------------------------------//

// MARK: POST --> create new reply inside /forum/forumid/topics

// 1- Get which forum we are in
// 2- check if user is found inside session i.e: logged in
// 3- grab "title", "body" from stencil
// 4- Get details of reply: Date, fourm, user, parent, title. type
//  save them in DB as JSON

router.post("/forum/:forumid/:messageid?") {
    request, response, next in
    
    // 1-
    guard let forumID = request.parameters["forumid"] else {
        try response.status(.badRequest).end()
        return
    }
    
    // 2-
    guard let username = request.session?["username"].string else {
        send(error: "You are not logged in", code: .forbidden, to: response)
        return
    }
    
    // 3-
    guard let fields = getPost(for: request, fields: ["title", "body"]) else {
        send(error: "Missing required fields", code: .badRequest, to: response)
        return
    }
    
    
    var newMessage = [String: String]()
    
    // 4-
    newMessage["body"] = fields["body"]!
    
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
    newMessage["date"] = formatter.string(from: Date())
    
    newMessage["forum"] = forumID
    
    if let topicID = request.parameters["messageid"] {
        newMessage["parent"] = topicID
    } else {
        newMessage["parent"] = ""
    }
    
    newMessage["title"] = fields["title"]!
    newMessage["type"] = "message"
    newMessage["user"] = username
    
    let newMessageJSON = JSON(newMessage)
    
    // 5-
    database.create(newMessageJSON) { id, revision, doc, error in
        defer { next() }
        
        if error != nil {
            send(error: "msg could not be created", code: .internalServerError, to: response)
        } else if let id = id {
            
            if newMessage["parent"]! == "" {
                _ = try? response.redirect("/forum/\(forumID)/\(id)")
            } else {
                _ = try? response.redirect("/forum/\(forumID)/\(newMessage["parent"]!)")
            }
        }
    }
}

//------------------------------------------------------------------------------------//
//---------------------------    /users/login    -----------------------------//
//------------------------------------------------------------------------------------//
// MARK:- GET --> HTML: Login page

router.get("/users/login") {
    request, response, next in
    defer { next() }
    
    try response.render("users-login", context: [:])
}
//------------------------------------------------------------------------------------//

// MARK: POST --> CODE: Login page

// 1. Grab "username" and "password" strings from users-login.stencil
// 2. Retrieve from DB based on fields["username"]!
// 3. User is loaded/exists
// 4. check input pass same as in DB after hasing and decoding
// 5. save username in session
// 6. redirect

router.post("/users/login") {
    
    request, response, next in
    
    // Fileds Func -->
    // check if body data valid
    // check if JSON found in body
    // remove HTMLencoding
    // return Username/password as JSON
    if let fields = getPost(for: request, fields: ["username", "password"]) {
        
        // 2-
        database.retrieve(fields["username"]!) { doc, error in
            
            defer { next() }
            
            if error != nil {
                send(error: "Unable to load user.", code: .badRequest, to: response)
                
                // 3- User is loaded/exists
            } else if let doc = doc {
                
                // 4-
                // load the salt and password from docs
                let savedSalt = doc["salt"].stringValue
                let savedPassword = doc["password"].stringValue
                
                //hash user's input password with saved salt
                let testPassword = password(from: fields["password"]!, salt: savedSalt)
                
                //check that decoded same as saved
                if testPassword == savedPassword {
                    
                    
                    // 5- save username in session
                    // ["_id"] is usernames in CouchDB
                    request.session?["username"].string = doc["_id"].string
                    
                    //6- redirect
                    _ = try? response.redirect("/home")
                    
                    
                } else {
                    print("No match")
                }
            }
        }
    } else {
        send(error: "Missing required fields", code: .badRequest, to: response)
    }
}



//------------------------------------------------------------------------------------//
//-----------------------     /users/create"      ------------------------------------//
//------------------------------------------------------------------------------------//
// MARK:- GET --> HTML: create new user

router.get("/users/create") {
    request, response, next in
    defer { next() }
    
    try response.render("users-create", context: [:] )
}

//------------------------------------------------------------------------------------//
router.post("/users/create") {
    
    // MARK: POST --> CODE: create new user
    
    // 1- check if user exists
    // 2- create salt
    // 3- create user JSON
    // 4-  save it in DB
    
    request, response, next in
    defer { next() }
    
    guard let fields = getPost(for: request, fields: ["username", "password", "email"]) else {
        send(error: "Missing required fields", code: .badRequest, to: response)
        return
    }
    
    database.retrieve(fields["username"]!) { doc, error in
        if error != nil {
            // username doesn't exist!
            var newUser = [String: String]()
            newUser["_id"] = fields["username"]!
            newUser["type"] = "user"
            newUser["email"] = fields["email"]!
            
            
            let saltString: String
            
            // crypt pass
            if let salt = try? Random.generate(byteCount: 64) {
                saltString = CryptoUtils.hexString(from: salt)
            } else {
                // create hash (Join name + secret key) coz salt above failed
                saltString = (fields["username"]! + fields["password"]! + "project4").digest(using: .sha512)
            }
            
            newUser["salt"] = saltString
            newUser["password"] = password(from: fields["password"]!, salt: saltString)
            
            let newUserJSON = JSON(newUser)
            
            // save it in DB
            database.create(newUserJSON) { id, revision, doc, error in
                defer { next() }
                
                if doc != nil {
                    response.send("OK!")
                    _ = try? response.redirect("/home")
                    
                } else {
                    // error
                    send(error: "User could not be created", code: .internalServerError, to: response)
                }
            }
        } else {
            // username exists already!
            send(error: "User already exists", code: .badRequest, to: response)
        }
    }
}

//------------------------------------------------------------------------------------//
//--------------------------        /logout"      --------------------------------//
//------------------------------------------------------------------------------------//
// MARK:- logout

router.get("/login") {
    request, response, next in
    defer { next() }
    
    request.session?["username"].string = nil
    try response.render("home", context: [:])
}


Kitura.addHTTPServer(onPort: 8090, with: router)
Kitura.run()
