# Firebase Setup Guide for Goodwin

This guide explains how to configure Firebase and Firestore for the Goodwin wholesale pickup platform.

## Prerequisites

- Firebase account (https://firebase.google.com)
- Flutter Firebase plugins already added to pubspec.yaml
- Goodwin app environment configured

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create a new project called "Goodwin Wholesale"
3. Enable Google Analytics (optional)
4. Wait for project creation to complete

## Step 2: Enable Firestore Database

1. In Firebase Console, go to **Firestore Database**
2. Click **Create Database**
3. Select your region (e.g., `us-central1` or your regional choice)
4. Start in **Development Mode** (production rules later)
5. Wait for database initialization

## Step 3: Configure Authentication

1. Go to **Authentication**
2. Click **Get Started**
3. Enable **Phone** authentication provider
4. Add your test phone numbers (for development)
5. Enable **Email/Password** for admin testing (optional)

## Step 4: Create Firestore Collections

Run this initialization code in your Flutter app or manually create collections:

### Option A: Automatic Seeding (Recommended)

In your Flutter app, add this initialization:

```dart
// In main.dart or initialization code
import 'package:goodwin/core/services/firestore_product_repository.dart';
import 'package:goodwin/core/services/firestore_user_repository.dart';

Future<void> initializeFirebaseData() async {
  try {
    await FirestoreProductRepository().seedDemoData();
    await FirestoreUserRepository().seedDemoCustomers();
    print('Demo data seeded successfully!');
  } catch (e) {
    print('Error seeding data: $e');
  }
}
```

### Option B: Manual Creation

Create these collections in Firestore Console:

**1. categories**
```
Document ID: cat_clothing
{
  "id": "cat_clothing",
  "name": "Clothing",
  "slug": "clothing",
  "isActive": true,
  "createdAt": "2026-08-29T00:00:00.000Z"
}
```

**2. products**
```
Document ID: prod_1
{
  "id": "prod_1",
  "name": "Transparent Umbrella",
  "sku": "UMB-TR-001",
  "categoryId": "cat_accessories",
  "description": "Premium transparent umbrella",
  "wholesalePrice": 90,
  "mrp": 150,
  "minimumOrderQty": 1,
  "availableQty": 100,
  "lowStockThreshold": 15,
  "images": ["https://images.unsplash.com/..."],
  "isActive": true,
  "isFeatured": true,
  "isBestSeller": false,
  "gstRate": 5,
  "variantName": "Standard",
  "tags": ["umbrella", "rain"],
  "createdAt": "2026-08-29T00:00:00.000Z"
}
```

**3. users**
```
Document ID: cust_1
{
  "id": "cust_1",
  "name": "Riya Traders",
  "phone": "9876543210",
  "email": "riya@example.com",
  "shopName": "Riya Traders",
  "address": "Near Market Road",
  "city": "Katargam",
  "gstNumber": "27ABCDE1234F1Z9",
  "preferredPickupLocation": "Katargam Branch",
  "role": "customer",
  "isActive": true,
  "createdAt": "2026-08-29T00:00:00.000Z"
}
```

**4. orders** (Created automatically when orders are placed)

## Step 5: Configure Security Rules

For development, update Firestore rules:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow all reads/writes in development
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

For production, use stricter rules:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Customers can only see their own data
    match /users/{userId} {
      allow read: if request.auth.uid == userId;
      allow write: if request.auth.uid == userId;
    }
    
    // Products are public read-only
    match /products/{document=**} {
      allow read: if true;
      allow write: if false;
    }
    
    // Categories are public read-only
    match /categories/{document=**} {
      allow read: if true;
      allow write: if false;
    }
    
    // Customers can read their orders
    match /orders/{orderId} {
      allow read: if resource.data.customerId == request.auth.uid;
      allow create: if request.auth.uid != null;
    }
  }
}
```

## Step 6: Get Firebase Config

1. Go to **Project Settings** (gear icon)
2. Go to **Your apps**
3. Select iOS/Android
4. Download the config file:
   - **iOS**: `GoogleService-Info.plist` → `ios/Runner/`
   - **Android**: `google-services.json` → `android/app/`

## Step 7: Test the Connection

Run the app:

```bash
flutter run
```

**Expected behavior:**
- Login screen appears
- Demo user login works
- Admin login works
- Firestore data loads in real-time
- Orders are persisted to Firestore

## Troubleshooting

### "Firestore is not initialized"
- Ensure `ProviderScope` wraps your app in main.dart ✓ (already done)

### "Permission denied" errors
- Check Firestore security rules
- Verify user authentication
- Check collection paths match exactly

### "Collection not found"
- Ensure Firestore collections are created
- Run the seeding initialization
- Check Firestore Console for collection creation

### Demo data not showing
- Firestore falls back to demo data automatically
- Collections can be empty; app uses fallbacks

## Environment Variables

Optionally, set Firebase environment flags:

```bash
flutter run \
  -d <device-id> \
  --dart-define=USE_FIREBASE=true \
  --dart-define=APP_ENV=production
```

## Real-time Updates

The app uses Riverpod providers that watch Firestore collections in real-time:

- **customerOrdersProvider** - Watches user's orders
- **warehouseOrdersProvider** - Watches all warehouse orders
- **readyForPickupProvider** - Watches pickup-ready orders
- **dashboardProvider** - Real-time dashboard metrics

Changes in Firestore automatically update the UI.

## Next Steps

1. ✓ Firestore basic setup
2. Firebase Authentication OTP setup
3. Enable Firebase Storage for images
4. Set up Cloud Functions for business logic
5. Configure production security rules
6. Enable rate limiting and abuse protection

## Support

For Firebase documentation: https://firebase.google.com/docs
For Flutter Firebase: https://firebase.flutter.dev
