// import 'package:flutter/material.dart';
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// class LoginView extends StatefulWidget {
//   LoginView({Key? key, required this.fromHome}) : super(key: key);

//   bool fromHome;

//   @override
//   State<LoginView> createState() => _LoginViewState();
// }

// class _LoginViewState extends State<LoginView> with TickerProviderStateMixin {
//   final storage = new FlutterSecureStorage();

//   late AnimationController _controller;
//   final TextEditingController emailController = TextEditingController();
//   final TextEditingController passwordController = TextEditingController();

//   int _userID = 0;
//   String _username = "Username";
//   int _companyID = 0;
//   int? _userMappingID;
//   bool _valueRememberMe = false;
//   int _validateUserLogin = 1;
//   bool _isLoading = false;
//   List<UserCompanyLoginSelectionDto> companyList = [];

//   UserCompanyLoginSelectionDto _company = new UserCompanyLoginSelectionDto(
//       userMappingID: 0,
//       userTypeID: 0,
//       type: null,
//       companyName: "Select Company",
//       isDeletedTemporarily: true);

//   @override
//   void initState() {
//     super.initState();

//     checkConnection();

//     _controller = AnimationController(
//       value: 0.0,
//       duration: Duration(seconds: 25),
//       upperBound: 1,
//       lowerBound: -1,
//       vsync: this,
//     )..repeat();
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     var size = MediaQuery.of(context).size;
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: SingleChildScrollView(
//         keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
//         child: Stack(
//           children: [
//             Column(
//               children: <Widget>[
//                 Stack(
//                   alignment: Alignment.center,
//                   children: [
//                     AnimatedBuilder(
//                       animation: _controller,
//                       builder: (BuildContext context, Widget? child) {
//                         return ClipPath(
//                           clipper: DrawClip(_controller.value),
//                           child: Container(
//                             height: size.height * 0.5,
//                             decoration: BoxDecoration(
//                               gradient: LinearGradient(
//                                 begin: Alignment.bottomLeft,
//                                 end: Alignment.topRight,
//                                 colors: [Color(0xFFFFA726), Color(0xFFE65100)],
//                               ),
//                             ),
//                           ),
//                         );
//                       },
//                     ),
//                     Container(
//                       padding: EdgeInsets.only(bottom: 30),
//                       child: Image.asset(
//                         'assets/images/cubehous_logo_blackNwhite.png',
//                         height: 120,
//                       ),
//                     ),
//                   ],
//                 ),
//                 Text(
//                   'Login to your Account',
//                   style: TextStyle(
//                       fontSize: 15,
//                       fontWeight: FontWeight.w500,
//                       fontStyle: FontStyle.italic),
//                 ),
//                 SizedBox(height: 10),
//                 Container(
//                   width: size.width * 0.8,
//                   margin: EdgeInsets.only(top: 20),
//                   child: TextField(
//                     controller: emailController,
//                     keyboardType: TextInputType.emailAddress,
//                     decoration: InputDecoration(
//                       hintText: 'Email',
//                       hintStyle:
//                           TextStyle(color: Color(0xFFACACAC), fontSize: 14),
//                       contentPadding:
//                           EdgeInsets.only(top: 20, bottom: 20, left: 20),
//                       enabledBorder: OutlineInputBorder(
//                         borderSide: BorderSide(color: Color(0xFFDADADA)),
//                         borderRadius: BorderRadius.all(Radius.circular(30.0)),
//                       ),
//                       focusedBorder: OutlineInputBorder(
//                         borderSide: BorderSide(color: Color(0xFFBDBDBD)),
//                         borderRadius: BorderRadius.all(Radius.circular(30.0)),
//                       ),
//                     ),
//                   ),
//                 ),
//                 Container(
//                   width: size.width * 0.8,
//                   margin: EdgeInsets.only(top: 18),
//                   child: TextField(
//                     controller: passwordController,
//                     obscureText: true,
//                     decoration: InputDecoration(
//                       hintText: 'Password',
//                       hintStyle:
//                           TextStyle(color: Color(0xFFACACAC), fontSize: 14),
//                       contentPadding:
//                           EdgeInsets.only(top: 20, bottom: 20, left: 20),
//                       enabledBorder: OutlineInputBorder(
//                         borderSide: BorderSide(color: Color(0xFFDADADA)),
//                         borderRadius: BorderRadius.all(Radius.circular(30.0)),
//                       ),
//                       focusedBorder: OutlineInputBorder(
//                         borderSide: BorderSide(color: Color(0xFFBDBDBD)),
//                         borderRadius: BorderRadius.all(Radius.circular(30.0)),
//                       ),
//                     ),
//                   ),
//                 ),

//                 ///Remember Me
//                 Container(
//                   width: size.width * 0.8,
//                   child: Row(
//                     children: [
//                       Checkbox(
//                         materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
//                         value: this._valueRememberMe,
//                         activeColor:
//                             GlobalColors.mainColor, // Color when active
//                         checkColor: Colors.white, // Checkmark color

//                         onChanged: (bool? value) {
//                           setState(() {
//                             this._valueRememberMe = value!;
//                           });
//                         },
//                       ),
//                       Text(
//                         "Remember Me",
//                         style: TextStyle(
//                           fontSize: 12,
//                           color: Colors.black87,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),

//                 SizedBox(height: 20),
//                 InkWell(
//                   onTap: () async {
//                     var connectivityResult =
//                         await Connectivity().checkConnectivity();
//                     if (connectivityResult == ConnectivityResult.none) {
//                       Get.defaultDialog(
//                         backgroundColor: Colors.white,
//                         title: "No Internet Connection",
//                         titleStyle: TextStyle(
//                           color: GlobalColors.mainColor,
//                           fontSize: 20,
//                           fontWeight: FontWeight.w600,
//                         ),
//                         titlePadding: EdgeInsets.only(top: 20),
//                         content: Container(
//                           padding: EdgeInsets.all(8.0),
//                           child: Column(
//                             children: [
//                               Center(
//                                 child: Text(
//                                   "Please check your internet.",
//                                   textAlign: TextAlign.center,
//                                 ),
//                               )
//                             ],
//                           ),
//                         ),
//                         confirm: TextButton(
//                           onPressed: () {
//                             Get.back();
//                           },
//                           style: TextButton.styleFrom(
//                             backgroundColor: GlobalColors.mainColor,
//                             padding: EdgeInsets.symmetric(horizontal: 15),
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(20),
//                               side: BorderSide(color: GlobalColors.mainColor),
//                             ),
//                           ),
//                           child: Text(
//                             "OK",
//                             style: TextStyle(color: Colors.white),
//                           ),
//                         ),
//                       );
//                     } else {
//                       fetchUsers();
//                     }
//                   },
//                   child: SizedBox(
//                     width: 100,
//                     height: 50,
//                     child: Container(
//                       alignment: Alignment.center,
//                       decoration: BoxDecoration(
//                         color: GlobalColors.mainColor,
//                         borderRadius: BorderRadius.circular(20),
//                         boxShadow: [
//                           BoxShadow(
//                             color: Colors.black.withOpacity(0.1),
//                             blurRadius: 10,
//                           )
//                         ],
//                       ),
//                       child: const Text(
//                         'Login',
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontWeight: FontWeight.w600,
//                           fontSize: 18,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//                 SizedBox(height: 20),
//               ],
//             ),
//             if (_isLoading)
//               Positioned.fill(
//                 child: Container(
//                   color: Colors.black.withOpacity(0.5),
//                   child: Center(
//                     child: LoadingPage(),
//                   ),
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> checkConnection() async {
//     var connectivityResult = await Connectivity().checkConnectivity();
//     if (connectivityResult == ConnectivityResult.none) {
//       Get.defaultDialog(
//         backgroundColor: Colors.white,
//         title: "No Internet Connection",
//         titleStyle: TextStyle(
//           color: GlobalColors.mainColor,
//           fontSize: 20,
//           fontWeight: FontWeight.w600,
//         ),
//         titlePadding: EdgeInsets.only(top: 20),
//         content: Container(
//           padding: EdgeInsets.all(8.0),
//           child: Column(
//             children: [
//               Center(
//                 child: Text(
//                   "Please check your internet.",
//                   textAlign: TextAlign.center,
//                 ),
//               )
//             ],
//           ),
//         ),
//         confirm: TextButton(
//           onPressed: () {
//             Get.back();
//           },
//           style: TextButton.styleFrom(
//             backgroundColor: GlobalColors.mainColor,
//             padding: EdgeInsets.symmetric(horizontal: 15),
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(20),
//               side: BorderSide(color: GlobalColors.mainColor),
//             ),
//           ),
//           child: Text(
//             "OK",
//             style: TextStyle(color: Colors.white),
//           ),
//         ),
//       );
//     } else {
//       checkVersion();
//     }
//   }

//   void checkVersion() async {
//     String secretKey = "FGBpUTp3Msn2w9j";
//     String versionCode = "9.0.12.21";

//     final response = await BaseClient()
//         .get('/VersionCheck/GetMobileAppVersionInfo?secretKey=${secretKey}');

//     if (response.statusCode == 200) {
//       if (response.body != null && response.body.isNotEmpty) {
//         final Map<String, dynamic> responseData = jsonDecode(response.body);
//         String versionNo = responseData['versionNo'];
//         if (versionNo == versionCode) {
//         } else {
//           bool updateRequire = responseData['isForce'];
//           if (updateRequire) {
//             showUpdateDialog();
//             return;
//           } else {
//             showUpdateDialog2();
//           }
//         }
//       }
//     }

//     checkLogin();
//   }

//   void checkLogin() async {
//     int token = await getToken();
//     if (token == 1) {
//       if (!widget.fromHome) {
//         await storeTokenAndData();
//       }
//     }
//   }

//   Future<int> getToken() async {
//     String? nUserID = await storage.read(key: "userid");
//     String? nUsername = await storage.read(key: "username");
//     String? nEmail = await storage.read(key: "email");
//     String? nPassword = await storage.read(key: "usercredential");
//     String? nCompanyID = await storage.read(key: "companyid");
//     String? nRemember = await storage.read(key: "remember");
//     String? nUserMappingID = await storage.read(key: "userMappingID");

//     String? nCompany = await storage.read(key: "company");

//     if (nCompany != null && nCompany.isNotEmpty) {
//       _company = UserCompanyLoginSelectionDto.deserialize(nCompany);
//     }

//     // if (_company != null) {
//     //   company = companylist[0];
//     // }

//     if (nUserID != null &&
//         nUsername != null &&
//         nEmail != null &&
//         nPassword != null &&
//         nCompanyID != null &&
//         nRemember != null &&
//         nUserMappingID != null) {
//       setState(() {
//         _userID = int.tryParse(nUserID) ?? 0;
//         _username = nUsername;
//         emailController.text = nEmail;
//         passwordController.text = nPassword;
//         _companyID = int.tryParse(nCompanyID) ?? 0;
//         _userMappingID = int.tryParse(nUserMappingID) ?? 0;
//         _valueRememberMe = (nRemember == "true");
//       });

//       final response3 = await BaseClient().get(
//         '/User/ValidateMobileRemember?email=' +
//             Uri.encodeComponent(nEmail) +
//             '&password=' +
//             Uri.encodeComponent(nPassword),
//       );

//       if (response3.statusCode == 200) {
//         if (response3.body != null && response3.body.isNotEmpty) {
//           if (!_valueRememberMe) {
//             return 0;
//           } else {
//             return int.parse(response3.body);
//           }
//         } else {
//           CommonUtils.showErrorToast(context, 'Please try again');
//           return 0;
//         }
//       } else {
//         CommonUtils.showErrorToast(context, 'Please try again');
//         return 0;
//       }
//     } else {
//       return 0;
//     }
//   }

//   Future<void> storeTokenAndData() async {
//     final response = await BaseClient().get(
//         '/User/CreateUserSession?usermappingid=' + _userMappingID.toString());

//     if (response.statusCode == 200) {
//       if (response.body != null) {
//         final Map<String, dynamic> responseData = jsonDecode(response.body);
//         List<dynamic> dynamicAccessRights = responseData['userAccessRights'];

//         // Convert List<dynamic> to List<String>
//         List<String> accessRights = List<String>.from(dynamicAccessRights);
//         Provider.of<UserAccessRightsProvider>(context, listen: false)
//             .setAccessRights(accessRights);

//         final int defaultLocationID =
//             responseData['userSession']['defaultLocationID'];
//         final String userSessionID =
//             responseData['userSession']['userSessionID'];
//         final String companyGUID = responseData['userSession']['companyGUID'];
//         final String apiKey = responseData['userSession']['apiKey'];
//         final bool isEnableTax = responseData['userSession']['isEnableTax'];
//         final bool isAutoBatchNo = responseData['userSession']['isAutoBatchNo'];
//         final String? batchNoFormat =
//             responseData['userSession']['batchNoFormat'];
//         final int salesDecimalPoint =
//             responseData['userSession']['salesDecimalPoint'];
//         final int purchaseDecimalPoint =
//             responseData['userSession']['purchaseDecimalPoint'];
//         final int quantityDecimalPoint =
//             responseData['userSession']['quantityDecimalPoint'];
//         final int costDecimalPoint =
//             responseData['userSession']['costDecimalPoint'];

//         String nEnableTax = isEnableTax.toString();
//         String nAutoBatch = isAutoBatchNo.toString();

//         await storage.write(key: "username", value: _username);
//         await storage.write(key: "companyName", value: _company.companyName);
//         await storage.write(
//             key: "company",
//             value: UserCompanyLoginSelectionDto.serialize(_company));
//         await storage.write(key: "email", value: emailController.text);
//         await storage.write(
//             key: "usercredential", value: passwordController.text);
//         await storage.write(
//             key: "remember", value: _valueRememberMe.toString());
//         await storage.write(key: "userid", value: _userID.toString());
//         await storage.write(key: "companyid", value: _companyID.toString());
//         await storage.write(
//             key: "defaultLocation", value: defaultLocationID.toString());
//         await storage.write(
//             key: "userSessionID", value: userSessionID.toString());
//         await storage.write(key: "companyGUID", value: companyGUID);
//         await storage.write(key: "apiKey", value: apiKey);
//         await storage.write(key: "isEnableTax", value: nEnableTax);
//         await storage.write(key: "isAutoBatchNo", value: nAutoBatch);
//         await storage.write(key: "batchNoFormat", value: batchNoFormat);
//         await storage.write(
//             key: "salesDecimalPoint", value: salesDecimalPoint.toString());
//         await storage.write(
//             key: "purchaseDecimalPoint",
//             value: purchaseDecimalPoint.toString());
//         await storage.write(
//             key: "quantityDecimalPoint",
//             value: quantityDecimalPoint.toString());
//         await storage.write(
//             key: "costDecimalPoint", value: costDecimalPoint.toString());

//         await BaseClient().get('/User/UpdateMobileRemember?email=' +
//             emailController.text +
//             '&grant=1');

//         Get.offAll(() => Home());
//       } else {
//         print('User Session Response is empty');
//         CommonUtils.showErrorToast(context, 'You have no access');
//       }
//     } else if (response.statusCode == 401) {
//       print(
//           'Create User Session Error: ${response.statusCode}: ${response.body}');
//       CommonUtils.showErrorToast(context, 'You have no access');
//     } else {
//       CommonUtils.showErrorToast(context, '');
//     }
//   }

//   void fetchUsers() async {
//     setState(() {
//       _isLoading = true;
//     });
//     if (!emailController.text.isEmpty && !passwordController.text.isEmpty) {
//       try {
//         final response = await BaseClient().get(
//             '/User/ValidateUserLogin?email=${emailController.text}&password=${passwordController.text}');

//         if (response.statusCode == 200) {
//           _validateUserLogin = int.tryParse(response.body) ?? 0;

//           if (_validateUserLogin > 0) {
//             final response2 = await BaseClient()
//                 .get('/User/GetUser?userid=${_validateUserLogin}');

//             final body = jsonDecode(response2.body);
//             String username = body['name'];

//             if (body != null) {
//               setState(() {
//                 _username = username.isNotEmpty ? username : "";
//                 _userID = _validateUserLogin;
//               });

//               int noOfCompany = await getCompanyList();
//               if (noOfCompany == 1) {
//                 skipCompanySelection();
//               } else {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => LoginCompany(
//                       email: emailController.text,
//                       password: passwordController.text,
//                       isRemember: _valueRememberMe,
//                       userID: _userID,
//                       username: _username,
//                     ),
//                   ),
//                 );
//               }
//             } else {
//               CommonUtils.showErrorToast(context, '');
//             }
//           }
//         } else {
//           print('Log In Error: ${response.statusCode}');
//           CommonUtils.showErrorToast(context, 'Invalid email or password');
//           passwordController.clear();
//         }
//       } catch (e) {
//         print('Login exception: ${e}');
//         CommonUtils.showErrorToast(context, '');
//       }
//     } else if (emailController.text.isEmpty) {
//       CommonUtils.showErrorToast(context, 'Please enter your email address');
//     } else if (passwordController.text.isEmpty) {
//       CommonUtils.showErrorToast(context, 'Please enter your password');
//     }
//     setState(() {
//       _isLoading = false;
//     });
//   }

//   Future<int> getCompanyList() async {
//     try {
//       final response = await BaseClient()
//           .get('/User/GetCompanySelectionList?userid=${_userID}');

//       List<UserCompanyLoginSelectionDto> _companyList =
//           UserCompanyLoginSelectionDto.userFromJson(response.body);

//       setState(() {
//         companyList = _companyList;
//       });
//     } catch (e) {
//       print('Company Selection Exception: ${e}');
//       CommonUtils.showErrorToast(context, '');
//     }

//     return companyList.length;
//   }

//   void skipCompanySelection() async {
//     setState(() {
//       _company = companyList[0];
//       _userMappingID = _company.userMappingID;
//       _companyID = _company.companyID!;
//     });

//     if (_company.companyID != null) {
//       await storeTokenAndData();
//     }
//   }

//   //Force app update
//   void showUpdateDialog() {
//     Get.defaultDialog(
//       backgroundColor: Colors.white,
//       barrierDismissible: false,
//       title: "App Update Required",
//       titleStyle: TextStyle(
//         fontSize: 20,
//         fontWeight: FontWeight.w600,
//         color: GlobalColors.mainColor,
//       ),
//       titlePadding: EdgeInsets.only(top: 20),
//       content: Container(
//         padding: EdgeInsets.all(8.0),
//         child: Column(
//           children: [
//             Center(
//               child: Text(
//                 "A new version of the app is available. Please update to continue.",
//                 textAlign: TextAlign.center,
//               ),
//             )
//           ],
//         ),
//       ),
//       confirm: TextButton(
//         onPressed: () async {
//           // Get.back();
//           // Redirect to the Play Store or App Store
//           // _launchStore();
//           if (Platform.isAndroid) {
//             Get.back();
//             exit(0);
//           } else if (Platform.isIOS) {
//             // iOS: Do nothing or show a blocking UI
//           }
//         },
//         style: TextButton.styleFrom(
//           backgroundColor: GlobalColors.mainColor,
//           padding: EdgeInsets.symmetric(horizontal: 15),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(20),
//             side: BorderSide(color: GlobalColors.mainColor),
//           ),
//         ),
//         child: Text(
//           "Update Now",
//           style: TextStyle(color: Colors.white),
//         ),
//       ),
//     );
//   }

//   //Update Available
//   void showUpdateDialog2() {
//     Get.defaultDialog(
//       backgroundColor: Colors.white,
//       barrierDismissible: false,
//       title: "New Update Available",
//       titleStyle: TextStyle(
//         fontSize: 20,
//         fontWeight: FontWeight.w600,
//         color: GlobalColors.mainColor,
//       ),
//       titlePadding: EdgeInsets.only(top: 20),
//       content: Container(
//         padding: EdgeInsets.all(8.0),
//         child: Column(
//           children: [
//             Center(
//               child: Text(
//                 "A new version of the app is available.",
//                 textAlign: TextAlign.center,
//               ),
//             )
//           ],
//         ),
//       ),
//       confirm: TextButton(
//         onPressed: () async {
//           Get.back();
//         },
//         style: TextButton.styleFrom(
//           backgroundColor: GlobalColors.mainColor,
//           padding: EdgeInsets.symmetric(horizontal: 15),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(20),
//             side: BorderSide(color: GlobalColors.mainColor),
//           ),
//         ),
//         child: Text(
//           "OK",
//           style: TextStyle(color: Colors.white),
//         ),
//       ),
//     );
//   }

//   Future<void> _launchStore() async {
//     String url;

//     if (Platform.isAndroid) {
//       // Play Store URL for Android
//       url =
//           'https://play.google.com/store/apps/details?id=com.presoft.cubehous';
//     } else if (Platform.isIOS) {
//       // App Store URL for iOS
//       url = 'https://apps.apple.com/us/app/cubehous';
//     } else {
//       // Optionally handle other platforms or show an error
//       url = '';
//     }

//     if (url.isNotEmpty) {
//       if (await canLaunch(url)) {
//         await launch(url);
//       }
//       // else {
//       //   throw 'Could not open the store.';
//       // }
//     }
//   }
// }

// class DrawClip extends CustomClipper<Path> {
//   double move = 0;
//   double slice = math.pi;
//   DrawClip(this.move);

//   @override
//   Path getClip(Size size) {
//     Path path = Path();
//     path.lineTo(0, size.height * 0.8);
//     double xCenter =
//         size.width * 0.5 + (size.width * 0.8 + 1) * math.sin(move * slice);
//     double yCenter = size.height * 0.8 + 69 * math.cos(move * slice);
//     path.quadraticBezierTo(xCenter, yCenter, size.width, size.height * 0.8);

//     path.lineTo(size.width, 0);
//     return path;
//   }

//   @override
//   bool shouldReclip(CustomClipper<Path> oldClipper) {
//     return true;
//   }
// }

// // 1. Check internet connection
// // 2. Check version
// // 3. checkLogin() [If true]
// // 3.1 Check device storage details : getToken()
// // - To get save userid, username, email, user credential, companied, remember, userMappingID, company.
// // 3.2 callAPI: User/ValidateMobileRemember
// // 3.3 storeTokenAndData()
// // 3.3.1 callAPI: User/CreateUserSession
// // 3.3.2 callAPI: User/UpdateMobileRemember
// // 3.3.3 Login to Home Page
// // 4. [If false]
// // 4.1 Wait user key in email and password,4.2 fetchUsers()
// // 4.2.1 callAPI: User/ValidateUserLogin
// // 4.2.2 callAPI: User/GetUser
// // 4.2.3 Check company List
// // 4.2.4 If only one, call storeTokenAndData() and direct to one page
// // 4.2.4 Else direct to company selection page
// //
// // Company Selection
// // 5. getCompanyList()
// // 5.1 call API: User/GetCompanySelectionList
// // 5.2 Once company selected, will set nUserMappingID, company, selectedCompanyID
// // 5.3 storeTokenAndData()