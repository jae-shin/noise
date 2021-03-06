const redis = require('./redis.js');
const activeSocketConnections = require('./activeSocketConnections');

////////////////////////////////////
//////// REDIS MESSAGE FUNCTIONS
////////////////////////////////////

/*
  Input Parameters
    friends = { 
      friendID: largestMessageID
      friendID: largestMessageID
      ...
    }

  Return value
    Array of objs for each friend
      {
        friendID
        messages: Array of msgObjs [ {targetID, sourceID, createdAt, body, msgID} ]
        largestMessageID
      }


  Edge Cases:
    1) "friends" obj is empty -> will return []
    2) no new messages to fetch for a certain friend: 
      the "messages" and "largestMessageID" fields will be null for that friend
 */
function retrieveNewMessages(userID, friends, clientSocket) {
  
  let result = [],
    smallerID,
    largerID,
    largestMessageID,
    newMessages,
    getMsgIDsPromiseArray = [],
    getMsgsPromiseArray = [];
  

  Object.keys(friends).forEach(friendID => {
    
    largestMessageID = friends[friendID];

    [smallerID, largerID] = userID < friendID ? [userID, friendID] : [friendID, userID];

    getMsgIDsPromiseArray.push(
      redis.client.zrangebyscoreAsync(`chat:${smallerID}:${largerID}`, (largestMessageID + 1), '+inf')
        .then(msgIDs => {
          if (msgIDs.length === 0) {
            // no new messages for friendID
            return null;

          } else {

            let getMsgsPromiseArray = [];
            
            msgIDs.forEach(msgID => {
              getMsgsPromiseArray.push(
                redis.client.hgetallAsync(`msgs:${msgID}`)
                  .then(msg => {
                    msg.msgID = msgID;
                    return msg;
                  })
                  .catch(console.error.bind(console))
              );
            });

            return Promise.all(getMsgsPromiseArray);
          }
        })
        .then(arrayOfNewMessagesPerFriend => {
          if (arrayOfNewMessagesPerFriend === null) {
            return {
              friendID,
              messages: null,
              latestMessageID: null
            };
          } else {
            return {
              friendID,
              messages: arrayOfNewMessagesPerFriend,
              latestMessageID: arrayOfNewMessagesPerFriend[arrayOfNewMessagesPerFriend.length - 1].msgID
            };
          }
        })
        .catch(console.error.bind(console))
    );

  });

  Promise.all(getMsgIDsPromiseArray).then(returnValue => {
    /*
    ///////// Testing
    let cnt = 1;
    //console.log('returnValue is:', returnValue);
    returnValue.forEach(obj => {
      console.log(`returnValue for obj ${cnt}:`, obj);
      cnt++;
    });
    */
    
    clientSocket.emit('redis response for retrieveNewMessages', returnValue);
    
  })
  .catch(console.error.bind(console));

}

/*
  Input Parameters
    message = { sourceID, targetID, body, createdAt }

  Return value
    TO: clientSocket
      userArray[0] = messageID (generated when inserting new message to redis)

    TO: targetID's socket
      userArray[0] = messageID
      userArray[1] = msgObj { sourceID, targetID, body, createdAt }
 */
function handleNewMessage(message, clientSocket) {
  // write new message to db
  redis.client.incr('global_msgID', redis.print);
  redis.client.getAsync('global_msgID')
    .then(msgID => {

      let timeStamp = Date.now();

      redis.client.hmset(`msgs:${msgID}`, [
        'sourceID', message.sourceID,
        'targetID', message.targetID,
        'body', message.body,
        'createdAt', `${timeStamp}`
      ]);

      [smallerID, largerID] = message.sourceID < message.targetID ? [message.sourceID, message.targetID] : [message.targetID, message.sourceID];
      redis.client.zadd(`chat:${smallerID}:${largerID}`, `${msgID}`, `${msgID}`);

      clientSocket.emit('successfully sent new message', 
        {
          messageID: msgID, 
          createdAt: timeStamp
        }
      );

      // check if friend (target of msg) is online
      let friendSocketID = activeSocketConnections[`${message.targetID}`];

      if (friendSocketID) {
        message.messageID = msgID;
        message.createdAt = timeStamp;
        clientSocket.broadcast.to(friendSocketID)
          .emit('receive new message', message);
      }
    })
    .catch(console.error.bind(console));
}



// ///////// Testing
// let friends = {
//   '1': 58, // [3, 10, 15, 22, 27, 34, 39, 46, 51, 58]
//   '2': 30 // [6, 11, 18, 23, 30, 35, 42, 47, 54, 59]
// };
// retrieveNewMessages(4, friends);

module.exports = {
  retrieveNewMessages,
  handleNewMessage
};