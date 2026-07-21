const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendNotification = functions.https.onRequest(async (req, res) => {
  // Enable CORS
  res.set('Access-Control-Allow-Origin', '*');
  
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    res.status(204).send('');
    return;
  }
  
  try {
    const { to, title, body } = req.body;
    
    if (!to || !title || !body) {
      return res.status(400).json({ error: 'Missing required parameters' });
    }

    const message = {
      token: to,
      notification: {
        title: title,
        body: body,
      },
      data: req.body.data || {},
      android: {
        notification: {
          channel_id: 'ride_sharing_notifications',
        },
      },
    };

    await admin.messaging().send(message);
    return res.status(200).json({ success: true });
  } catch (error) {
    console.error('Error sending notification:', error);
    return res.status(500).json({ error: error.message });
  }
});