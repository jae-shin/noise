const app = require('express')();
const http = require('http').Server(app);
const io = require('socket.io')(http);
const utils = require('./utils.js');

// Redis Database
const redis = require('./redis.js');
const userController = require('./userController.js');

app.get('/', function(request, response) {
  response.send('hello world');
});

http.listen(4000, function() {
  console.log('Server listening at port 4000');
});

// forDummyData
let users = [];

io.on('connection', function(clientSocket) {
  console.log('A user connected with socket id', clientSocket.id);
  

  clientSocket.on('disconnect', function() {
    console.log('A user disconnected with socket id', clientSocket.id);
  });


  clientSocket.on('signIn', function(user) {
    console.log('hit signIn on server socket:', user);
    userController.signIn(user, clientSocket);
  });

  clientSocket.on('userSigningUp', function(user) {
      console.log('hit signUp on server socket: ', user);
      userController.signUp(user, clientSocket);
  });

  clientSocket.on('encryptedChatSent', function(chatMessage) {
  	console.log('TEST: chatMessage from client on server', chatMessage)
  	//insert msg id -time stamp to ordered list
    //insert msg hash to msgs
  });

  clientSocket.on('noisifiedChatSent', function(chatMessage) {
	console.log('TODO: pass nosified chatMessage to redis DB')
	//clientSocket.emit('c', chatMessage);
  });

  clientSocket.on('friendAdded', function(chatMessage) {
  console.log('TODO: pass friend')
  //clientSocket.emit('c', chatMessage);
  });

  clientSocket.on('getfriends', function() {
    var dummyFriends = ["Ryan", "Jae", "Michael", "Hannah"]
    io.emit(dummyFriends);

  });

  clientSocket.on('signinOrSignup', function(username) {
    users.push(username)
    console.log(username, 'connected and userscount is', users.length, username )
  });
});
