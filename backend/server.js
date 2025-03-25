const express = require('express');
const multer = require('multer');
const bodyParser = require('body-parser');
const dotenv = require('dotenv');
const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');
const axios = require('axios');
const FormData = require('form-data');
const cors = require('cors');
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

dotenv.config(); // โหลด environment variables จากไฟล์ .env

const app = express();

// ตั้งค่า CORS โดยกำหนด options
app.use(cors({
  // ระบุ origin ที่ต้องการอนุญาต (หรือใช้ '*' เพื่ออนุญาตทุก origin)
  origin: '*', 
  // ระบุ HTTP methods ที่อนุญาต
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  // ระบุ headers ที่อนุญาตให้ส่งไปกับ request
  allowedHeaders: ['Content-Type', 'Authorization']
}));

// ถ้าต้องการรองรับ Preflight (OPTIONS) request ให้เพิ่มบรรทัดนี้
app.options('*', cors());



admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'catface-notify',
});


app.use(express.json());
// ตั้งค่าเชื่อมต่อ PostgreSQL
const pool = new Pool({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT,
});

// ตั้งค่าการอัปโหลดไฟล์
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const tempDir = path.join(__dirname, 'uploads', 'temp');
    if (!fs.existsSync(tempDir)) {
      fs.mkdirSync(tempDir, { recursive: true });
    }
    cb(null, tempDir); // เก็บไฟล์ชั่วคราวใน temp
  },
  filename: (req, file, cb) => {
    const timestamp = Date.now();
    cb(null, `${timestamp}_${file.originalname}`);
  },
});

const upload = multer({ storage });

// ตั้งค่า storage สำหรับ user profile
const userProfileStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    const destDir = path.join(__dirname, 'uploads', 'user_profile');
    if (!fs.existsSync(destDir)) {
      fs.mkdirSync(destDir, { recursive: true });
    }
    cb(null, destDir);
  },
  filename: (req, file, cb) => {
    const userId = req.params.id;
    const ext = path.extname(file.originalname);
    const destDir = path.join(__dirname, 'uploads', 'user_profile');

    // ลบไฟล์เก่าที่มีชื่อขึ้นต้นด้วย userId
    fs.readdir(destDir, (err, files) => {
      if (err) {
        console.error('Error reading directory:', err);
        return cb(err);
      }
      files.forEach((fileName) => {
        if (fileName.startsWith(userId)) {
          fs.unlink(path.join(destDir, fileName), (err) => {
            if (err) console.error('Error deleting file:', err);
          });
        }
      });
      // กำหนดชื่อไฟล์ใหม่
      cb(null, userId + ext);
    });
  },
});


// สร้าง instance สำหรับ user profile uploads
const userProfileUpload = multer({ storage: userProfileStorage });



// Middleware
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));
app.use('/users_profiles', express.static(path.join(__dirname, 'users_profiles')));
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));


const identifyAndMatch = async (postId, postType) => {
  try {
    console.log(`🔍 Identifying post ${postId} (${postType})...`);

    // ดึงรูปแรกของโพสต์
    const imageQuery = await pool.query(
      `SELECT image_path FROM ${postType === 'found' ? 'foundpostimage' : 'lostpostimage'} WHERE post_id = $1 LIMIT 1`,
      [postId]
    );

    if (imageQuery.rows.length === 0) {
      console.log(`⚠️ No image found for post ${postId}`);
      return;
    }

    const imagePath = imageQuery.rows[0].image_path;
    console.log(`📸 Using image: ${imagePath}`);

    // ส่งรูปไปให้โมเดล identify
    const formData = new FormData();
    formData.append("file", fs.createReadStream(imagePath));

    const response = await axios.post("http://localhost:3000/identify/", formData, {
      headers: formData.getHeaders(),
    });

    const matches = response.data.result || [];
    if (matches.length === 0) {
      console.log(`⚠️ No match found for post ${postId} (NoMatch)`);
      return;
    }

    console.log(`✅ Found ${matches.length} matches! Processing...`);

    // สำหรับแต่ละ match ที่พบ
    for (const match of matches) {
      const matchedPostId = parseInt(match.label);
      const distance = parseFloat(match.distance);

      // เงื่อนไขสำหรับโพสต์ที่เพิ่มเป็น foundcatpost
      if (postType === "found" && String(matchedPostId).startsWith("1")) {
        // เมื่อโพสต์ foundcatpost match กับ lostcatpost ให้บันทึก match
        await pool.query(
          `INSERT INTO matchpost (lost_post_id, found_post_id, distance) VALUES ($1, $2, $3)`,
          [matchedPostId, postId, distance]
        );
        console.log(`🔗 Matched Found Post ${postId} with Lost Post ${matchedPostId} (Distance: ${distance})`);

        // ดึงข้อมูลจาก lostcatpost เพื่อส่ง notification ให้ผู้ใช้ที่โพสต์ foundcatpost
        const lostPostResult = await pool.query(
          `SELECT user_id, cat_id FROM lostcatpost WHERE post_id = $1`,
          [matchedPostId]
        );
        if (lostPostResult.rows.length > 0) {
          const lostUserId = lostPostResult.rows[0].user_id;
          // ดึง cat_name จากตาราง cat โดยใช้ cat_id
          const catId = lostPostResult.rows[0].cat_id;
          const catNameResult = await pool.query(
            `SELECT cat_name FROM cat WHERE cat_id = $1`,
            [catId]
          );
          let catName = 'แมวของคุณ';
          if (catNameResult.rows.length > 0) {
            catName = catNameResult.rows[0].cat_name;
          }
          // ดึง location จาก foundcatpost (postId ที่เพิ่งเพิ่ม) เพื่อแสดงในข้อความ
          const foundPostData = await pool.query(
            `SELECT location FROM foundcatpost WHERE post_id = $1`,
            [postId]
          );
          let location = "ไม่ทราบตำแหน่ง";
          if (foundPostData.rows.length > 0 && foundPostData.rows[0].location) {
            location = foundPostData.rows[0].location;
          }
          // ดึง fcm_token ของเจ้าของ lostcatpost
          const userResult = await pool.query(
            `SELECT fcm_token FROM Users WHERE user_id = $1`,
            [lostUserId]
          );
          if (userResult.rows.length > 0 && userResult.rows[0].fcm_token) {
            const token = userResult.rows[0].fcm_token;
            console.log(`🚀 Found FCM token for lost post user (${lostUserId}): ${token}`);
            // สำหรับ foundcatpost ให้ส่ง payload เฉพาะ lostPostId (match กับ lostcatpost)
            const message = {
              token: token,
              notification: {
                title: `มีคนพบเจอแมวที่คล้ายกับ ${catName}!`,
                body: 'ตรวจสอบโพสต์ที่พบ',
              },
              data: {
                
                foundPostId: postId.toString(),
              },
            };
            try {
              const sendResponse = await admin.messaging().send(message);
              console.log('✅ Successfully sent notification:', sendResponse);
            } catch (error) {
              console.error('❌ Error sending notification:', error);
            }
          } else {
            console.log(`⚠️ No FCM token found for lost post user ${lostUserId}`);
          }
        } else {
          console.log(`⚠️ No lost post found with post_id ${matchedPostId} to fetch user_id and cat_id`);
        }
      }
      // เงื่อนไขสำหรับโพสต์ที่เพิ่มเป็น lostcatpost
      else if (postType === "lost" && String(matchedPostId).startsWith("2")) {
        // เมื่อโพสต์ lostcatpost match กับ foundcatpost ให้บันทึก match
        await pool.query(
          `INSERT INTO matchpost (lost_post_id, found_post_id, distance) VALUES ($1, $2, $3)`,
          [postId, matchedPostId, distance]
        );
        console.log(`🔗 Matched Lost Post ${postId} with Found Post ${matchedPostId} (Distance: ${distance})`);

        // ดึงข้อมูลจาก foundcatpost เพื่อส่ง notification ให้ผู้ใช้ที่โพสต์ lostcatpost
        const foundPostResult = await pool.query(
          `SELECT user_id FROM foundcatpost WHERE post_id = $1`,
          [matchedPostId]
        );
        if (foundPostResult.rows.length > 0) {
          const foundUserId = foundPostResult.rows[0].user_id;
          // ดึง fcm_token ของเจ้าของ foundcatpost
          const userResult = await pool.query(
            `SELECT fcm_token FROM Users WHERE user_id = $1`,
            [foundUserId]
          );
          if (userResult.rows.length > 0 && userResult.rows[0].fcm_token) {
            const token = userResult.rows[0].fcm_token;
            console.log(`🚀 Found FCM token for found post user (${foundUserId}): ${token}`);
            // สำหรับ lostcatpost ให้ส่ง payload เฉพาะ foundPostId (match กับ foundcatpost)
            const message = {
              token: token,
              notification: {
                title: 'แมวที่คุณพบเจอคล้ายกับโพสต์ตามหาของใครบางคน!',
                body: 'ตรวจสอบโพสต์ที่ตามหาที่ match กับโพสต์ของคุณ',
              },
              data: {
                lostPostId: postId.toString(),
              },
            };
            try {
              const sendResponse = await admin.messaging().send(message);
              console.log('✅ Successfully sent notification:', sendResponse);
            } catch (error) {
              console.error('❌ Error sending notification:', error);
            }
          } else {
            console.log(`⚠️ No FCM token found for found post user ${foundUserId}`);
          }
        } else {
          console.log(`⚠️ No found post found with post_id ${matchedPostId} to fetch user_id`);
        }
      } else {
        console.log(`⏭️ Skipping match ${matchedPostId} (Same type: ${postType})`);
      }
    }
  } catch (error) {
    console.error(`⚠️ Error in identifyAndMatch:`, error);
  }
};



app.post('/register-cat', upload.array('images', 5), async (req, res) => {
  const { cat_name, cat_breed, cat_color, cat_prominent_point, user_id } = req.body;

  if (!cat_name || !cat_breed || !cat_color || !cat_prominent_point || !user_id) {
    return res.status(400).json({ error: 'All fields are required' });
  }

  try {
    // เพิ่มข้อมูลแมวในฐานข้อมูล
    const result = await pool.query(
      'INSERT INTO Cat (user_id, cat_name, cat_breed, cat_color, cat_prominent_point) VALUES ($1, $2, $3, $4, $5) RETURNING cat_id',
      [user_id, cat_name, cat_breed, cat_color, cat_prominent_point]
    );

    const cat_id = result.rows[0].cat_id;

    // ✅ สร้างโฟลเดอร์แรก: uploads/catimage/{cat_id}
    const catDir = path.join(__dirname, 'uploads', 'catimage', String(cat_id));
    if (!fs.existsSync(catDir)) {
      console.log(`Creating directory for cat images: ${catDir}`);
      fs.mkdirSync(catDir, { recursive: true });
    }

    // ✅ สร้างโฟลเดอร์ที่สอง: /home/catface/NUT_MODEL/MAIN/MOCKUP_DB/{cat_id}
    //const mockupDir = path.join('/home/catface/NUT_MODEL/MAIN/MOCKUP_DB', String(cat_id));
    //if (!fs.existsSync(mockupDir)) {
      //console.log(`Creating directory for mockup images: ${mockupDir}`);
      //fs.mkdirSync(mockupDir, { recursive: true });
    //}

    let index = 1;
    for (let file of req.files) {
      const formattedIndex = String(index).padStart(2, '0');
      const imageId = parseInt(`${cat_id}${formattedIndex}`, 10);
      const fileExtension = path.extname(file.originalname);
      const imagePath = `uploads/catimage/${cat_id}/${imageId}${fileExtension}`;
      //const mockupPath = path.join(mockupDir, `${imageId}${fileExtension}`);

      // ✅ ย้ายไฟล์ไปที่ uploads/catimage/{cat_id}
      fs.renameSync(file.path, path.join(__dirname, imagePath));

      // ✅ คัดลอกไฟล์ไปที่ MOCKUP_DB/{cat_id}
      //fs.copyFileSync(path.join(__dirname, imagePath), mockupPath);

      // ✅ เพิ่มข้อมูลรูปภาพลงในฐานข้อมูล
      await pool.query(
        'INSERT INTO CatImage (cat_id, image_id, image_path) VALUES ($1, $2, $3)',
        [cat_id, imageId, imagePath]
      );

      index++;
    }

    res.status(201).json({ message: 'Cat registered successfully', cat_id });
  } catch (err) {
    console.error('Error registering cat:', err);
    res.status(500).json({ error: 'Something went wrong' });
  }
});


app.post('/register-user', async (req, res) => {
  const { username, email, password, phone_number, address } = req.body;

  try {
    // ตรวจสอบว่าอีเมลนี้มีอยู่แล้วหรือไม่
    const existingUser = await pool.query('SELECT * FROM users WHERE email = $1', [email]);

    if (existingUser.rows.length > 0) {
      return res.status(400).json({ error: 'Email already exists' });
    }

    // แฮชรหัสผ่าน (แนะนำให้ใช้ bcrypt)
    const hashedPassword = password; // ใช้ bcrypt.hash(password, salt) ในระบบจริง
    const defaultProfilePath = 'users_profiles/unknown.png';

    // เพิ่มผู้ใช้ใหม่ในฐานข้อมูลและคืนค่า user_id
    const newUser = await pool.query(
      'INSERT INTO users (username, email, password, phone_number, address, profile_image_path) VALUES ($1, $2, $3, $4, $5, $6) RETURNING user_id',
      [username, email, hashedPassword, phone_number, address, defaultProfilePath]
    );

    if (newUser.rows.length > 0) {
      res.status(201).json({
        message: 'User registered successfully',
        user_id: newUser.rows[0].user_id,
      });
    } else {
      res.status(500).json({ error: 'Failed to retrieve user_id' });
    }
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Endpoint สำหรับ Sign-in
app.post('/sign-in', async (req, res) => {
  const { email, password } = req.body;

  try {
    const result = await pool.query(
      'SELECT user_id FROM Users WHERE email = $1 AND password = $2',
      [email, password]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    const userId = result.rows[0].user_id;
    res.status(200).json({ user_id: userId });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.get('/get-user/:id', async (req, res) => {
  const userId = req.params.id;

  try {
    const { rows } = await pool.query(
      'SELECT username, profile_image_path FROM users WHERE user_id = $1',
      [userId]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    // ส่งข้อมูลผู้ใช้กลับไป
    res.json({
      username: rows[0].username,
      profile_image_path: rows[0].profile_image_path, // Path รูปโปรไฟล์
    });
  } catch (error) {
    console.error('Error fetching user data:', error);
    res.status(500).json({ error: 'Failed to fetch user data' });
  }
});

app.get('/get-user-info/:id', async (req, res) => {
  const userId = req.params.id;

  try {
    const { rows } = await pool.query(
      'SELECT username, profile_image_path, email, phone_number FROM users WHERE user_id = $1',
      [userId]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    // ส่งข้อมูลผู้ใช้กลับไป
    res.json({
      username: rows[0].username,
      profile_image_path: rows[0].profile_image_path, // Path รูปโปรไฟล์
      email: rows[0].email,
      phone_number: rows[0].phone_number
    });
  } catch (error) {
    console.error('Error fetching user data:', error);
    res.status(500).json({ error: 'Failed to fetch user data' });
  }
});


app.get('/get-cats/:user_id', async (req, res) => {
  const userId = req.params.user_id;

  try {
    const cats = await pool.query(
      `SELECT c.cat_id, c.cat_name, c.cat_breed, c.cat_color, c.cat_prominent_point, c.state,
              (
                SELECT ci.image_path 
                FROM CatImage ci 
                WHERE ci.cat_id = c.cat_id 
                ORDER BY ci.image_id ASC 
                LIMIT 1
              ) AS image_path
       FROM Cat c
       WHERE c.user_id = $1`,
      [userId]
    );

    res.status(200).json(cats.rows);
  } catch (err) {
    console.error('Error fetching cats:', err);
    res.status(500).json({ error: 'Failed to fetch cats' });
  }
});



app.post('/lost-cat-post', upload.array('images', 5), async (req, res) => {
  console.log('Request Body:', req.body);
  console.log('Uploaded Files:', req.files);

  const {
    user_id,
    cat_id,
    location,
    time,
    breed,
    color,
    prominent_point,
    latitude,
    longitude
  } = req.body;

  try {
    // 1) เพิ่มโพสต์ Lost Cat ลงในตาราง lostcatpost
    const result = await pool.query(
      `INSERT INTO lostcatpost (user_id, cat_id, location, time, breed, color, prominent_point, latitude, longitude)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING post_id`,
      [user_id, cat_id, location, time, breed, color, prominent_point, latitude, longitude]
    );

    const postId = result.rows[0].post_id;
    console.log('Created lostcatpost with post_id:', postId);

    // 2) อัปเดตสถานะของแมวในตาราง Cat เป็น 'lost'
    await pool.query(
      `UPDATE cat SET state = 'lost' WHERE cat_id = $1`,
      [cat_id]
    );

    // 3) เตรียมโฟลเดอร์สำหรับเก็บรูปใน "uploads/lostpostimage/{postId}"
    const relativeDir = `uploads/lostpostimage/${postId}`;
    const absoluteDir = path.join(__dirname, relativeDir);
    if (!fs.existsSync(absoluteDir)) {
      fs.mkdirSync(absoluteDir, { recursive: true });
      console.log('Created directory in lostpostimage:', absoluteDir);
    }

    // 4) สร้างโฟลเดอร์ใน MOCKUP_DB
    const baseDir = '/home/catface/NUT_MODEL/MAIN/MOCKUP_DB';
    const mockupDir = path.join(baseDir, String(postId));
    if (!fs.existsSync(mockupDir)) {
      fs.mkdirSync(mockupDir, { recursive: true });
      console.log('Created directory in MOCKUP_DB:', mockupDir);
    }

    // 5) จัดการรูปภาพ (สูงสุด 5 รูป) ที่อัปโหลดมา
    for (let i = 0; i < req.files.length; i++) {
      const file = req.files[i];
      // กำหนด imageId (เช่น 100002701, 100002702, ...)
      const imageId = `${postId}${String(i + 1).padStart(2, '0')}`;
      const imageExtension = path.extname(file.originalname);

      // กำหนด relative path สำหรับเก็บใน DB
      // เช่น "uploads/lostpostimage/{postId}/{imageId}.jpg"
      const relativeImagePath = `${relativeDir}/${imageId}${imageExtension}`;
      const absoluteImagePath = path.join(__dirname, relativeImagePath);

      console.log(`Moving file ${file.path} to ${absoluteImagePath} and copying to ${mockupDir}`);

      // คัดลอกไฟล์จาก temp ไปยังโฟลเดอร์ปลายทาง
      fs.copyFileSync(file.path, absoluteImagePath);

      // คัดลอกไปยัง MOCKUP_DB
      const mockupImagePath = path.join(mockupDir, `${imageId}${imageExtension}`);
      fs.copyFileSync(file.path, mockupImagePath);

      // บันทึกข้อมูลรูปภาพในตาราง lostpostimage โดยเก็บ relative path
      await pool.query(
        `INSERT INTO lostpostimage (post_id, image_id, image_path) VALUES ($1, $2, $3)`,
        [postId, imageId, relativeImagePath]
      );
    }

    // 6) ลบไฟล์ชั่วคราวหลังจากคัดลอกเสร็จ
    for (const file of req.files) {
      if (fs.existsSync(file.path)) {
        fs.unlinkSync(file.path);
      }
    }

    // 7) ตอบกลับและเรียกฟังก์ชัน identifyAndMatch
    res.status(201).json({
      message: 'Lost cat post created successfully',
      post_id: postId
    });
    identifyAndMatch(postId, "lost");

  } catch (err) {
    console.error('Error creating lost cat post:', err);
    res
      .status(500)
      .json({ error: 'Failed to create lost cat post', details: err.message });
  }
});


app.post('/found-cat-post', upload.array('images', 5), async (req, res) => {
  const {
    user_id,
    location,
    time,
    breed,
    color,
    prominent_point,
    latitude,
    longitude
  } = req.body;

  try {
    // เพิ่มโพสต์ Found Cat ลงในตาราง foundcatpost (โดยไม่มี cat_id)
    const postResult = await pool.query(
      `INSERT INTO foundcatpost (user_id, location, time, breed, color, prominent_point, latitude, longitude)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING post_id`,
      [user_id, location, time, breed, color, prominent_point, latitude, longitude]
    );

    const postId = postResult.rows[0].post_id;
    console.log(`✅ Created found cat post with ID: ${postId}`);

    // กำหนด relative directory สำหรับเก็บรูปโพสต์ (จะได้ path แบบ "uploads/foundpostimage/{postId}")
    const relativeDir = `uploads/foundpostimage/${postId}`;
    const absoluteDir = path.join(__dirname, relativeDir);
    if (!fs.existsSync(absoluteDir)) {
      fs.mkdirSync(absoluteDir, { recursive: true });
      console.log(`📂 Created directory for found post images: ${absoluteDir}`);
    }

    // สร้างโฟลเดอร์ใน MOCKUP_DB (ตามที่ต้องการ)
    const mockupDir = path.join('/home/catface/NUT_MODEL/MAIN/MOCKUP_DB', String(postId));
    if (!fs.existsSync(mockupDir)) {
      fs.mkdirSync(mockupDir, { recursive: true });
      console.log(`📂 Created directory in MOCKUP_DB: ${mockupDir}`);
    }

    // บันทึกรูปภาพของโพสต์ Found Cat
    for (let i = 0; i < req.files.length; i++) {
      const imageId = `${postId}${String(i + 1).padStart(2, '0')}`; // เช่น 200000101
      const imageExtension = path.extname(req.files[i].originalname);

      // กำหนด relative path ที่จะเก็บในฐานข้อมูล (เช่น "uploads/foundpostimage/{postId}/{imageId}.jpg")
      const relativeImagePath = `${relativeDir}/${imageId}${imageExtension}`;
      // สร้าง absolute path สำหรับบันทึกไฟล์จริง
      const absoluteImagePath = path.join(__dirname, relativeImagePath);

      console.log(`📸 Saving image ${req.files[i].path} to ${absoluteImagePath} and copying to MOCKUP_DB`);

      // คัดลอกไฟล์จากตำแหน่งชั่วคราวไปยัง absoluteImagePath
      fs.copyFileSync(req.files[i].path, absoluteImagePath);
      // คัดลอกไฟล์ไปยัง MOCKUP_DB
      const mockupImagePath = path.join(mockupDir, `${imageId}${imageExtension}`);
      fs.copyFileSync(req.files[i].path, mockupImagePath);

      // บันทึกข้อมูลรูปภาพลงในตาราง foundpostimage โดยเก็บ relative path
      await pool.query(
        `INSERT INTO foundpostimage (post_id, image_id, image_path) VALUES ($1, $2, $3)`,
        [postId, imageId, relativeImagePath]
      );
    }

    // ลบไฟล์ต้นฉบับในตำแหน่งชั่วคราวออก
    for (const file of req.files) {
      if (fs.existsSync(file.path)) {
        fs.unlinkSync(file.path);
      }
    }

    // เพิ่มคะแนนให้ผู้ใช้ (บวก 10 คะแนน)
    await pool.query(
      `UPDATE users SET point = point + 10 WHERE user_id = $1`,
      [user_id]
    );
    console.log(`👍 Added 10 points to user ${user_id}`);

    // ตอบกลับว่าโพสต์ถูกสร้างเรียบร้อย
    res.status(201).json({
      message: 'Found cat post created successfully',
      post_id: postId
    });

    // เรียกฟังก์ชัน identifyAndMatch เพื่อตรวจจับและจับคู่ (ถ้ามีการใช้งาน)
    identifyAndMatch(postId, "found");

  } catch (err) {
    console.error('⚠️ Error creating found cat post:', err);
    res.status(500).json({ error: 'Failed to create found cat post', details: err.message });
  }
});


app.get('/get-user-cats/:user_id', async (req, res) => {
  const { user_id } = req.params;

  try {
    const result = await pool.query(
      'SELECT cat_id, cat_name FROM Cat WHERE user_id = $1',
      [user_id]
    );

    res.status(200).json(result.rows);
  } catch (err) {
    console.error('Error fetching user cats:', err);
    res.status(500).json({ error: 'Failed to fetch user cats' });
  }
});

app.get('/get-cat-images/:cat_id', async (req, res) => {
  const { cat_id } = req.params;

  try {
    // ดึงข้อมูลรูปภาพจากฐานข้อมูล
    const result = await pool.query(
      'SELECT image_path FROM CatImage WHERE cat_id = $1',
      [cat_id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'No images found for the given cat_id' });
    }

    // ส่งข้อมูลรูปภาพกลับไป
    res.status(200).json(result.rows);
  } catch (err) {
    console.error('Error fetching cat images:', err);
    res.status(500).json({ error: 'Failed to fetch cat images' });
  }
});


// Endpoint สำหรับรับรูปภาพจาก Client และส่งไปยัง API ที่รันบน Docker
app.post('/identify-cat', upload.single('image'), async (req, res) => {
  try {
      if (!req.file) {
          return res.status(400).json({ error: 'No image file uploaded' });
      }

      // สร้าง FormData เพื่อส่งรูปไปยัง API ที่รันบน Docker
      const formData = new FormData();
      formData.append('file', fs.createReadStream(req.file.path), {
          filename: req.file.originalname,
          contentType: 'image/jpeg' // หรือ image/png ตามไฟล์ที่อัปโหลด
      });

      // เรียกใช้ API ที่รันอยู่บน Docker
      const response = await axios.post('http://0.0.0.0:3000/identify/', formData, {
          headers: {
              ...formData.getHeaders()
          }
      });

      // ลบไฟล์ที่อัปโหลดเพื่อประหยัดพื้นที่
      fs.unlinkSync(req.file.path);

      // ส่งผลลัพธ์ที่ได้รับจาก API กลับไปยัง Client
      res.json(response.data);

  } catch (error) {
      console.error('Error identifying cat:', error);
      res.status(500).json({ error: 'Failed to identify cat' });
  }
});

app.get('/get-all-posts', async (req, res) => {
  try {
    //ดึงโพสต์ Lost Cat พร้อมกับรูปภาพ
    const lostPosts = await pool.query(`
      SELECT 
        lcp.post_id, 
        lcp.user_id, 
        lcp.cat_id, 
        lcp.location, 
        lcp.time,(lcp.time AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Bangkok') AS time, 
        lcp.breed, 
        lcp.color, 
        lcp.prominent_point, 
        lcp.latitude, 
        lcp.longitude,
        COALESCE(
          json_agg(
            json_build_object(
              'image_id', lpi.image_id,
              'image_path', lpi.image_path
            )
          ) FILTER (WHERE lpi.image_id IS NOT NULL), '[]'
        ) AS images
      FROM lostcatpost lcp
      LEFT JOIN lostpostimage lpi ON lcp.post_id = lpi.post_id
      GROUP BY lcp.post_id
      ORDER BY lcp.time DESC
    `);

    //ดึงโพสต์ Found Cat พร้อมกับรูปภาพ
    const foundPosts = await pool.query(`
      SELECT 
        fcp.post_id, 
        fcp.user_id, 
        fcp.location, 
        fcp.time,(fcp.time AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Bangkok') AS time,  
        fcp.breed, 
        fcp.color, 
        fcp.prominent_point, 
        fcp.latitude, 
        fcp.longitude,
        COALESCE(
          json_agg(
            json_build_object(
              'image_id', fpi.image_id,
              'image_path', fpi.image_path
            )
          ) FILTER (WHERE fpi.image_id IS NOT NULL), '[]'
        ) AS images
      FROM foundcatpost fcp
      LEFT JOIN foundpostimage fpi ON fcp.post_id = fpi.post_id
      GROUP BY fcp.post_id
      ORDER BY fcp.time DESC
    `);

    res.status(200).json({
      lostPosts: lostPosts.rows,
      foundPosts: foundPosts.rows
    });

  } catch (err) {
    console.error('Error fetching posts:', err);
    res.status(500).json({ error: 'Failed to fetch posts' });
  }
});

app.get('/user-cat-lost/:user_id', async (req, res) => {
  const { user_id } = req.params;

  try {
      // SQL Query เพื่อดึง cat_id และ cat_name ของแมวที่หายของ user นี้
      const query = `
          SELECT cat_id, cat_name
          FROM cat
          WHERE user_id = $1 AND state = 'lost'
          ORDER BY cat_id ASC;
      `;

      const result = await pool.query(query, [user_id]);

      if (result.rows.length === 0) {
          return res.status(404).json({ message: 'No lost cats found for this user' });
      }

      res.status(200).json(result.rows);
  } catch (error) {
      console.error('Error fetching lost cats:', error);
      res.status(500).json({ error: 'Failed to retrieve lost cats' });
  }
});

app.get('/matched-posts/:cat_id', async (req, res) => {
  const { cat_id } = req.params;

  try {
      // 🔍 ดึง post_id จาก lostcatpost ที่มี cat_id นั้น
      const lostPostQuery = `
          SELECT post_id 
          FROM lostcatpost 
          WHERE cat_id = $1;
      `;

      const lostPostResult = await pool.query(lostPostQuery, [cat_id]);

      if (lostPostResult.rows.length === 0) {
          return res.status(404).json({ message: 'No lost posts found for this cat' });
      }

      const lostPostIds = lostPostResult.rows.map(row => row.post_id);

      // 🔍 ดึง foundcatpost ที่ match กับ lostcatpost จาก matchpost
      const matchQuery = `
          SELECT m.found_post_id, m.distance, 
                 f.user_id, f.location, f.time,(f.time AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Bangkok') AS time, f.breed, f.color, f.prominent_point, f.latitude, f.longitude,
                 COALESCE(array_agg(fp.image_path) FILTER (WHERE fp.image_path IS NOT NULL), '{}') AS images
          FROM matchpost m
          JOIN foundcatpost f ON m.found_post_id = f.post_id
          LEFT JOIN foundpostimage fp ON f.post_id = fp.post_id
          WHERE m.lost_post_id = ANY($1::bigint[])
          GROUP BY m.found_post_id, m.distance, f.user_id, f.location, f.time, f.breed, f.color, f.prominent_point, f.latitude, f.longitude
          ORDER BY m.distance ASC;
      `;

      const matchResult = await pool.query(matchQuery, [lostPostIds]);

      if (matchResult.rows.length === 0) {
          return res.status(404).json({ message: 'No matching found posts for this cat' });
      }

      res.status(200).json(matchResult.rows);
  } catch (error) {
      console.error('Error fetching matched posts:', error);
      res.status(500).json({ error: 'Failed to retrieve matched posts' });
  }
});


app.post('/confirm-found-cat', async (req, res) => {
  try {
    const { cat_id } = req.body;

    if (!cat_id) {
      return res.status(400).json({ error: 'cat_id is required' });
    }

    // 1. ค้นหา lost post ของแมวตัวนั้นโดยใช้ cat_id
    const postQuery = await pool.query(
      'SELECT post_id FROM lostcatpost WHERE cat_id = $1 LIMIT 1',
      [cat_id]
    );

    if (postQuery.rows.length === 0) {
      return res.status(404).json({ error: 'Lost post not found for the given cat_id' });
    }

    const lost_post_id = postQuery.rows[0].post_id;
    console.log(`Found lost post_id ${lost_post_id} for cat_id ${cat_id}`);

    // 2. ลบ record ในตาราง lostcatpost
    await pool.query('DELETE FROM lostcatpost WHERE post_id = $1', [lost_post_id]);

    // 3. อัปเดตสถานะแมวให้เป็น 'home'
    await pool.query('UPDATE cat SET state = $1 WHERE cat_id = $2', ['home', cat_id]);

    // 4. ลบโฟลเดอร์ของโพสต์ใน lostpostimage
    const lostPostFolder = path.join(__dirname, 'uploads', 'lostpostimage', String(lost_post_id));
    if (fs.existsSync(lostPostFolder)) {
      fs.rmSync(lostPostFolder, { recursive: true, force: true });
      console.log(`Deleted folder: ${lostPostFolder}`);
    } else {
      console.log(`Folder not found: ${lostPostFolder}`);
    }

    // 5. ลบโฟลเดอร์ใน MOCKUP_DB
    const mockupFolder = path.join('/home/catface/NUT_MODEL/MAIN/MOCKUP_DB', String(lost_post_id));
    if (fs.existsSync(mockupFolder)) {
      fs.rmSync(mockupFolder, { recursive: true, force: true });
      console.log(`Deleted folder: ${mockupFolder}`);
    } else {
      console.log(`Folder not found: ${mockupFolder}`);
    }

    return res.status(200).json({
      message: 'Confirmed: lost post removed, cat state updated to home, and folders deleted'
    });
  } catch (error) {
    console.error('Error in confirm-found-cat:', error);
    return res.status(500).json({ error: error.message });
  }
});

app.get('/user-profile/:user_id', async (req, res) => {
  const { user_id } = req.params;
  try {
    // SELECT user_id, username, profile_image_path, points FROM users WHERE user_id=?
    const result = await pool.query(
      'SELECT user_id, username, profile_image_path, point FROM users WHERE user_id=$1',
      [user_id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    return res.status(200).json(result.rows[0]);
  } catch (error) {
    console.error('Error user-profile:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

app.post('/redeem-reward', async (req, res) => {
  try {
    const { user_id, reward_id } = req.body;
    if (!user_id || !reward_id) {
      return res.status(400).json({ error: 'user_id and reward_id are required' });
    }

    // ดึงข้อมูล user (คอลัมน์ชื่อ "point")
    const userResult = await pool.query(
      'SELECT point FROM users WHERE user_id = $1',
      [user_id]
    );
    if (userResult.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    const userPoint = userResult.rows[0].point;

    // กำหนด requiredPoint ตาม reward_id (Reward แบบ fix)
    let requiredPoint = 0;
    switch (reward_id) {
      case 'R001':
        requiredPoint = 15;
        break;
      case 'R002':
        requiredPoint = 15;
        break;
      case 'R003':
        requiredPoint = 10;
        break;
      case 'R004':
        requiredPoint = 20;
        break;
      case 'R005':
        requiredPoint = 25;
        break;
      default:
        return res.status(400).json({ error: 'Invalid reward_id' });
    }

    // เช็คว่าคะแนนพอหรือไม่
    if (userPoint < requiredPoint) {
      return res.status(400).json({ error: 'Point ของคุณไม่เพียงพอ' });
    }

    // หักคะแนนออก
    const newPoint = userPoint - requiredPoint;
    await pool.query(
      'UPDATE users SET point = $1 WHERE user_id = $2',
      [newPoint, user_id]
    );

    // (ถ้าต้องการบันทึกประวัติการแลก Reward สามารถ INSERT ลงตาราง user_rewards ได้ที่นี่)

    return res.status(200).json({
      message: 'Redeemed reward successfully',
      newPoint
    });
  } catch (error) {
    console.error('Error in redeem-reward:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});


app.post('/update-user-info/:id', userProfileUpload.single('profile_image'), async (req, res) => {
  try {
    const userId = req.params.id;
    const { username, email, phone_number } = req.body;
    let newProfileImagePath;

    if (req.file) {
      // ไฟล์ที่อัปโหลดจะถูกเก็บไว้ใน uploads/user_profile โดยใช้ชื่อ userId.ext
      newProfileImagePath = 'uploads/user_profile/' + req.file.filename;
    } else {
      // fallback: ดึง path เดิมจาก DB (ในกรณีที่ไม่มีไฟล์ใหม่ส่งมา)
      const { rows } = await pool.query(
        'SELECT profile_image_path FROM users WHERE user_id = $1',
        [userId]
      );
      if (rows.length === 0) {
        return res.status(404).json({ error: 'User not found' });
      }
      newProfileImagePath = rows[0].profile_image_path;
    }

    // อัปเดตข้อมูลในฐานข้อมูล
    const updateQuery = `
      UPDATE users
      SET username = $1,
          email = $2,
          phone_number = $3,
          profile_image_path = $4
      WHERE user_id = $5
      RETURNING user_id
    `;
    const result = await pool.query(updateQuery, [
      username,
      email,
      phone_number,
      newProfileImagePath,
      userId,
    ]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    res.status(200).json({ message: 'User updated successfully' });
  } catch (error) {
    console.error('Error updating user data:', error);
    res.status(500).json({ error: 'Failed to update user data' });
  }
});

app.get('/get-user-posts/:user_id', async (req, res) => {
  const { user_id } = req.params;

  try {
    // ดึงโพสต์ Lost Cat ของ user_id นั้น
    const lostPosts = await pool.query(`
      SELECT 
        lcp.post_id, 
        lcp.user_id, 
        lcp.cat_id, 
        lcp.location, 
        lcp.time, 
        lcp.breed, 
        lcp.color, 
        lcp.prominent_point, 
        lcp.latitude, 
        lcp.longitude,
        COALESCE(
          json_agg(
            json_build_object(
              'image_id', lpi.image_id,
              'image_path', lpi.image_path
            )
          ) FILTER (WHERE lpi.image_id IS NOT NULL), '[]'
        ) AS images
      FROM lostcatpost lcp
      LEFT JOIN lostpostimage lpi ON lcp.post_id = lpi.post_id
      WHERE lcp.user_id = $1
      GROUP BY lcp.post_id
      ORDER BY lcp.time DESC
    `, [user_id]);

    // ดึงโพสต์ Found Cat ของ user_id นั้น
    const foundPosts = await pool.query(`
      SELECT 
        fcp.post_id, 
        fcp.user_id, 
        fcp.location, 
        fcp.time, 
        fcp.breed, 
        fcp.color, 
        fcp.prominent_point, 
        fcp.latitude, 
        fcp.longitude,
        COALESCE(
          json_agg(
            json_build_object(
              'image_id', fpi.image_id,
              'image_path', fpi.image_path
            )
          ) FILTER (WHERE fpi.image_id IS NOT NULL), '[]'
        ) AS images
      FROM foundcatpost fcp
      LEFT JOIN foundpostimage fpi ON fcp.post_id = fpi.post_id
      WHERE fcp.user_id = $1
      GROUP BY fcp.post_id
      ORDER BY fcp.time DESC
    `, [user_id]);

    res.status(200).json({
      lostPosts: lostPosts.rows,
      foundPosts: foundPosts.rows
    });

  } catch (err) {
    console.error('Error fetching user posts:', err);
    res.status(500).json({ error: 'Failed to fetch user posts' });
  }
});


app.delete('/delete-lost-post/:post_id', async (req, res) => {
  const { post_id } = req.params;

  try {
    // 1) ดึงข้อมูลโพสต์ที่มีการใช้ post_id นี้ เพื่อหา cat_id
    const lostCatPostResult = await pool.query(
      'SELECT cat_id FROM lostcatpost WHERE post_id = $1',
      [post_id]
    );
    
    if (lostCatPostResult.rows.length === 0) {
      return res.status(404).json({ error: 'Lost post not found' });
    }

    const cat_id = lostCatPostResult.rows[0].cat_id;

    // 2) อัปเดตสถานะของแมวในตาราง cat ให้เป็น 'home'
    await pool.query(
      'UPDATE cat SET state = $1 WHERE cat_id = $2',
      ['home', cat_id]
    );

    // 3) ดึงข้อมูลภาพจากตาราง lostpostimage
    const imagesResult = await pool.query(
      'SELECT image_path FROM lostpostimage WHERE post_id = $1',
      [post_id]
    );
    const images = imagesResult.rows; // [{ image_path: 'uploads/lostpostimage/...' }, ...]

    // 4) ลบ record ในตาราง lostpostimage
    await pool.query('DELETE FROM lostpostimage WHERE post_id = $1', [post_id]);

    // 5) ลบ record ในตาราง lostcatpost
    await pool.query('DELETE FROM lostcatpost WHERE post_id = $1', [post_id]);

    // 6) ลบโฟลเดอร์ใน uploads/lostpostimage/{post_id} ถ้ามี
    const lostDir = path.join(__dirname, 'uploads', 'lostpostimage', String(post_id));
    if (fs.existsSync(lostDir)) {
      fs.rmSync(lostDir, { recursive: true, force: true });
      console.log(`Deleted lost post folder: ${lostDir}`);
    }

    // 7) ลบโฟลเดอร์ใน MOCKUP_DB/{post_id} ถ้ามี
    const mockupDir = path.join('/home/catface/NUT_MODEL/MAIN/MOCKUP_DB', String(post_id));
    if (fs.existsSync(mockupDir)) {
      fs.rmSync(mockupDir, { recursive: true, force: true });
      console.log(`Deleted mockup folder: ${mockupDir}`);
    }

    return res.status(200).json({ message: 'Lost post deleted successfully, and cat state updated to home' });
  } catch (err) {
    console.error('Error deleting lost post:', err);
    return res.status(500).json({ error: 'Failed to delete lost post' });
  }
});


// ลบโพสต์ Found Cat
app.delete('/delete-found-post/:post_id', async (req, res) => {
  const { post_id } = req.params;

  try {
    // 1) ดึงข้อมูลภาพจากตาราง foundpostimage
    const imagesResult = await pool.query(
      'SELECT image_path FROM foundpostimage WHERE post_id = $1',
      [post_id]
    );
    const images = imagesResult.rows; // [{ image_path: 'uploads/foundpostimage/...' }, ...]

    // 2) ลบ record ในตาราง foundpostimage
    await pool.query('DELETE FROM foundpostimage WHERE post_id = $1', [post_id]);

    // 3) ลบ record ในตาราง foundcatpost
    await pool.query('DELETE FROM foundcatpost WHERE post_id = $1', [post_id]);

    // 4) ลบโฟลเดอร์ใน uploads/foundpostimage/{post_id} ถ้ามี
    const foundDir = path.join(__dirname, 'uploads', 'foundpostimage', String(post_id));
    if (fs.existsSync(foundDir)) {
      fs.rmSync(foundDir, { recursive: true, force: true });
      console.log(`Deleted found post folder: ${foundDir}`);
    }

    // 5) ลบโฟลเดอร์ใน MOCKUP_DB/{post_id} ถ้ามี
    const mockupDir = path.join('/home/catface/NUT_MODEL/MAIN/MOCKUP_DB', String(post_id));
    if (fs.existsSync(mockupDir)) {
      fs.rmSync(mockupDir, { recursive: true, force: true });
      console.log(`Deleted mockup folder: ${mockupDir}`);
    }

    return res.status(200).json({ message: 'Found post deleted successfully' });
  } catch (err) {
    console.error('Error deleting found post:', err);
    return res.status(500).json({ error: 'Failed to delete found post' });
  }
});

// อัปเดต Lost Cat Post
app.put('/update-lost-post/:post_id', async (req, res) => {
  const { post_id } = req.params;
  const { breed, color, prominent_point, location } = req.body; // เพิ่ม location
  try {
    const result = await pool.query(
      `UPDATE lostcatpost
       SET breed = $1,
           color = $2,
           prominent_point = $3,
           location = $4
       WHERE post_id = $5
       RETURNING post_id`,
      [breed, color, prominent_point, location, post_id]
    );
    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Lost cat post not found' });
    }
    return res.status(200).json({ message: 'Lost cat post updated successfully' });
  } catch (err) {
    console.error('Error updating lost post:', err);
    return res.status(500).json({ error: 'Failed to update lost post' });
  }
});

// อัปเดต Found Cat Post
app.put('/update-found-post/:post_id', async (req, res) => {
  const { post_id } = req.params;
  const { breed, color, prominent_point, location } = req.body; // เพิ่ม location
  try {
    const result = await pool.query(
      `UPDATE foundcatpost
       SET breed = $1,
           color = $2,
           prominent_point = $3,
           location = $4
       WHERE post_id = $5
       RETURNING post_id`,
      [breed, color, prominent_point, location, post_id]
    );
    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Found cat post not found' });
    }
    return res.status(200).json({ message: 'Found cat post updated successfully' });
  } catch (err) {
    console.error('Error updating found post:', err);
    return res.status(500).json({ error: 'Failed to update found post' });
  }
});

app.post('/update-cat-info/:cat_id', upload.array('new_images', 5), async (req, res) => {
  const { cat_id } = req.params;
  const { cat_name, cat_breed, cat_color, cat_prominent_point, images_to_delete } = req.body;
  
  if (!cat_name || !cat_breed || !cat_color || !cat_prominent_point) {
    return res.status(400).json({ error: 'All fields are required' });
  }

  try {
    // 1. อัปเดตข้อมูลพื้นฐานของแมวในตาราง Cat
    const updateQuery = `
      UPDATE Cat
      SET cat_name = $1,
          cat_breed = $2,
          cat_color = $3,
          cat_prominent_point = $4
      WHERE cat_id = $5
      RETURNING cat_id
    `;
    const updateResult = await pool.query(updateQuery, [cat_name, cat_breed, cat_color, cat_prominent_point, cat_id]);
    if (updateResult.rows.length === 0) {
      return res.status(404).json({ error: 'Cat not found' });
    }

    // 2. จัดการรูปที่ต้องลบ (images_to_delete คาดว่าเป็น JSON array ของ URL หรือ identifier)
    if (images_to_delete) {
      let deleteList;
      try {
        deleteList = JSON.parse(images_to_delete);
      } catch (err) {
        return res.status(400).json({ error: 'Invalid images_to_delete format' });
      }
      for (let imagePath of deleteList) {
        // ลบไฟล์ออกจากระบบ (ตรวจสอบ path ที่ถูกต้อง)
        const fullPath = path.join(__dirname, imagePath);
        if (fs.existsSync(fullPath)) {
          fs.unlinkSync(fullPath);
        }
        // ลบ record ในฐานข้อมูล
        await pool.query(
          'DELETE FROM CatImage WHERE cat_id = $1 AND image_path = $2',
          [cat_id, imagePath]
        );
      }
    }

    // 3. จัดการรูปใหม่ที่อัพโหลด (ใน req.files)
    if (req.files && req.files.length > 0) {
      // หา index ของรูปใหม่เริ่มต้นที่มากกว่าจำนวนรูปเดิม
      let index = await currentImageIndex(cat_id); // เรียกแบบ await
      for (let file of req.files) {
        index++;
        const formattedIndex = String(index).padStart(2, '0');
        const imageId = parseInt(`${cat_id}${formattedIndex}`, 10);
        const fileExtension = path.extname(file.originalname);
        const imagePath = `uploads/catimage/${cat_id}/${imageId}${fileExtension}`;

        // ย้ายไฟล์ไปที่ uploads/catimage/{cat_id}
        fs.renameSync(file.path, path.join(__dirname, imagePath));

        // เพิ่ม record ในฐานข้อมูล
        await pool.query(
          'INSERT INTO CatImage (cat_id, image_id, image_path) VALUES ($1, $2, $3)',
          [cat_id, imageId, imagePath]
        );
      }
    }

    res.status(200).json({ message: 'Cat updated successfully' });
  } catch (error) {
    console.error('Error updating cat info:', error);
    res.status(500).json({ error: 'Failed to update cat info' });
  }
});

// ตัวอย่างฟังก์ชันสำหรับหาค่า index ล่าสุดของรูปใน cat image
async function currentImageIndex(cat_id) {
  const result = await pool.query('SELECT MAX(image_id) as max_index FROM CatImage WHERE cat_id = $1', [cat_id]);
  if (result.rows[0].max_index) {
    // สมมุติว่า image_id มีรูปแบบเป็น {cat_id}{formattedIndex}
    const maxIndex = result.rows[0].max_index.toString().slice(-2);
    return parseInt(maxIndex, 10);
  }
  return 0;
}



app.get('/get-cat-info/:cat_id', async (req, res) => {
  try {
    const { cat_id } = req.params;

    // ดึงข้อมูลแมวจากตาราง Cat
    const catResult = await pool.query(
      'SELECT cat_name, cat_breed, cat_color, cat_prominent_point FROM Cat WHERE cat_id = $1',
      [cat_id]
    );

    if (catResult.rows.length === 0) {
      return res.status(404).json({ error: 'Cat not found' });
    }

    const catData = catResult.rows[0];

    // ดึงรายการรูปภาพของแมวจากตาราง CatImage (เรียงตาม image_id)
    const imagesResult = await pool.query(
      'SELECT image_path FROM CatImage WHERE cat_id = $1 ORDER BY image_id',
      [cat_id]
    );

    // สร้าง Array ของ URL รูปภาพ
    const images = imagesResult.rows.map(row => row.image_path);

    // ส่งข้อมูลกลับไปยัง client
    res.status(200).json({
      cat_name: catData.cat_name,
      cat_breed: catData.cat_breed,
      cat_color: catData.cat_color,
      cat_prominent_point: catData.cat_prominent_point,
      images: images
    });
  } catch (error) {
    console.error('Error fetching cat info:', error);
    res.status(500).json({ error: 'Failed to fetch cat info' });
  }
});

app.post('/update-fcm-token', async (req, res) => {
  const { user_id, fcm_token } = req.body;
  try {
    await pool.query(
      `UPDATE Users SET fcm_token = $1 WHERE user_id = $2`,
      [fcm_token, user_id]
    );
    res.status(200).json({ message: 'FCM token updated successfully' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Endpoint สำหรับดึงข้อมูล foundcatpost ด้วย post_id
app.get('/foundcatpost/:postId', async (req, res) => {
  const postId = req.params.postId;
  try {
    const foundPost = await pool.query(`
      SELECT 
        fcp.post_id,
        fcp.user_id,
        fcp.location,
        fcp.time, 
        (fcp.time AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Bangkok') AS time,
        fcp.breed,
        fcp.color,
        fcp.prominent_point,
        fcp.latitude,
        fcp.longitude,
        COALESCE(
          json_agg(
            json_build_object(
              'image_id', fpi.image_id,
              'image_path', fpi.image_path
            )
          ) FILTER (WHERE fpi.image_id IS NOT NULL), '[]'
        ) AS images
      FROM foundcatpost fcp
      LEFT JOIN foundpostimage fpi ON fcp.post_id = fpi.post_id
      WHERE fcp.post_id = $1
      GROUP BY fcp.post_id
    `, [postId]);

    if (foundPost.rows.length === 0) {
      return res.status(404).json({ error: 'Post not found' });
    }
    res.status(200).json(foundPost.rows);
  } catch (err) {
    console.error('Error fetching foundcatpost:', err);
    res.status(500).json({ error: err.message });
  }
});

// Endpoint สำหรับดึงข้อมูล lostcatpost ด้วย post_id
app.get('/lostcatpost/:postId', async (req, res) => {
  const postId = req.params.postId;
  try {
    const lostPost = await pool.query(`
      SELECT 
        lcp.post_id,
        lcp.user_id,
        lcp.cat_id,
        lcp.location,
        lcp.time, 
        (lcp.time AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Bangkok') AS time,
        lcp.breed,
        lcp.color,
        lcp.prominent_point,
        lcp.latitude,
        lcp.longitude,
        COALESCE(
          json_agg(
            json_build_object(
              'image_id', lpi.image_id,
              'image_path', lpi.image_path
            )
          ) FILTER (WHERE lpi.image_id IS NOT NULL), '[]'
        ) AS images
      FROM lostcatpost lcp
      LEFT JOIN lostpostimage lpi ON lcp.post_id = lpi.post_id
      WHERE lcp.post_id = $1
      GROUP BY lcp.post_id
    `, [postId]);

    if (lostPost.rows.length === 0) {
      return res.status(404).json({ error: 'Post not found' });
    }
    res.status(200).json(lostPost.rows);
  } catch (err) {
    console.error('Error fetching lostcatpost:', err);
    res.status(500).json({ error: err.message });
  }
});

app.delete('/delete-cat/:catId', async (req, res) => {
  const { catId } = req.params;
  try {
    // 1) ตรวจสอบว่าแมวมีอยู่ในตาราง Cat หรือไม่
    const catResult = await pool.query('SELECT * FROM Cat WHERE cat_id = $1', [catId]);
    if (catResult.rows.length === 0) {
      return res.status(404).json({ error: 'Cat not found' });
    }

    // 2) ดึงข้อมูลรูปภาพจากตาราง CatImage สำหรับแมวนี้
    const imagesResult = await pool.query(
      'SELECT image_path FROM CatImage WHERE cat_id = $1',
      [catId]
    );
    const images = imagesResult.rows; // ตัวอย่าง: [{ image_path: 'uploads/catimage/123/12301.jpg' }, ...]

    // 3) ลบข้อมูลในตาราง CatImage ของแมวนี้
    await pool.query('DELETE FROM CatImage WHERE cat_id = $1', [catId]);

    // 4) ลบข้อมูลแมวในตาราง Cat
    await pool.query('DELETE FROM Cat WHERE cat_id = $1', [catId]);

    // 5) ลบไฟล์รูปภาพแต่ละไฟล์ที่อยู่ในตาราง CatImage
    for (const image of images) {
      const imagePath = path.join(__dirname, image.image_path);
      if (fs.existsSync(imagePath)) {
        fs.unlinkSync(imagePath);
        console.log(`Deleted cat image file: ${imagePath}`);
      }
    }

    // 6) ลบโฟลเดอร์ที่เก็บรูปแมว: uploads/catimage/{catId}
    const catDir = path.join(__dirname, 'uploads', 'catimage', String(catId));
    if (fs.existsSync(catDir)) {
      fs.rmSync(catDir, { recursive: true, force: true });
      console.log(`Deleted cat image directory: ${catDir}`);
    }

    // หากมีการสร้างโฟลเดอร์ MOCKUP_DB ให้ลบเพิ่มเติมตามที่จำเป็น
    // const mockupDir = path.join('/home/catface/NUT_MODEL/MAIN/MOCKUP_DB', String(catId));
    // if (fs.existsSync(mockupDir)) {
    //   fs.rmSync(mockupDir, { recursive: true, force: true });
    //   console.log(`Deleted cat mockup directory: ${mockupDir}`);
    // }

    return res.status(200).json({ message: 'Cat deleted successfully' });
  } catch (err) {
    console.error('Error deleting cat:', err);
    return res.status(500).json({ error: 'Failed to delete cat', details: err.message });
  }
});


// สตาร์ทเซิร์ฟเวอร์
const PORT = process.env.PORT || 5000;
app.listen(PORT,'0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
});
