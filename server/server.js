var app = require('express')();
var http = require('http').Server(app);
var io = require('socket.io')(http);

app.get('/', function(request, response) {
  response.send('hello world');
});

http.listen(4000, function() {
  console.log('listening')
})

io.on('connection', function(socket) {
  console.log('a user connected')

})
