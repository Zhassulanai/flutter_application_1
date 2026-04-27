# FamilyChat — Design Spec
Date: 2026-04-27

## Overview

A minimalist family messenger for Android and iOS. Works over local Wi-Fi only — no internet, no external server. Inspired by WhatsApp but stripped to essentials: text, images/video, and file sharing.

Target: 2–5 family members on the same home Wi-Fi network.

---

## Architecture

### Network Layer — mDNS + WebSocket P2P

Each device is simultaneously a WebSocket server and client. Devices discover each other via mDNS (`_familychat._tcp` service type) using the `multicast_dns` package.

Each device has a permanent UUID generated on first launch and stored in SharedPreferences. The UUID is used as the stable identity across IP changes (DHCP).

**Discovery flow:**
1. App starts → registers mDNS service with own UUID, name, IP, port
2. App scans for `_familychat._tcp` services every 10 seconds
3. On discovery → establishes WebSocket connection to peer
4. Maintains connection pool: one WebSocket per known peer

**Message delivery:**
- Messages saved to SQLite with status `pending` before sending
- On successful delivery → status updated to `delivered`
- When a peer comes online → pending messages for that peer are flushed automatically
- Media files transferred in 64KB chunks over the same WebSocket connection

### State Management — BLoC

- `ContactsBloc` — peer list, online status, mDNS events
- `ChatBloc` — messages per chat, send/receive, status updates
- `NetworkBloc` — WebSocket connection pool, message queue, chunk transfers

---

## Data Model (SQLite via sqflite)

### `contacts`
| column | type | notes |
|---|---|---|
| id | TEXT PK | UUID |
| name | TEXT | display name |
| avatar_path | TEXT | local file path |
| ip_address | TEXT | last known IP |
| port | INTEGER | WebSocket port |
| is_online | INTEGER | 0/1 |
| last_seen | INTEGER | unix timestamp |

### `chats`
| column | type | notes |
|---|---|---|
| id | TEXT PK | UUID |
| type | TEXT | `direct` or `group` |
| name | TEXT | group name only |
| last_message | TEXT | preview text |
| last_message_time | INTEGER | unix timestamp |
| unread_count | INTEGER | |

### `messages`
| column | type | notes |
|---|---|---|
| id | TEXT PK | UUID |
| chat_id | TEXT | FK → chats.id |
| sender_id | TEXT | FK → contacts.id |
| content | TEXT | text body or file name |
| content_type | TEXT | `text`, `image`, `video`, `file` |
| file_path | TEXT | local path for media |
| timestamp | INTEGER | unix timestamp |
| status | TEXT | `pending`, `sent`, `delivered` |
| is_outgoing | INTEGER | 0/1 |

### Wire format (JSON over WebSocket)
```json
{
  "id": "uuid",
  "chat_id": "uuid",
  "sender_id": "uuid",
  "type": "text|image|video|file",
  "content": "message text or empty for media",
  "file_name": "photo.jpg",
  "file_size": 204800,
  "chunk_index": 0,
  "total_chunks": 4,
  "timestamp": 1714200000
}
```

File size limit: 50MB per file.

**Group chat delivery:** A message sent to the group is delivered individually to each group member (broadcast). The sender's device sends one WebSocket message per online recipient. For offline recipients, the message is queued per-recipient in SQLite and delivered when each comes online. Group membership is stored locally — the group is created by one device and shared to others via a special `group_invite` message type.

**WebSocket port:** Fixed at 8765. Published via mDNS. Stored in the `contacts` table to handle cases where a peer changes the default.

---

## Screens & Navigation

### Onboarding (first launch only)
- Enter display name
- Optional: pick avatar photo
- Generates UUID, saves to SharedPreferences

### Chat List (home screen)
- Lists all chats: group first, then direct contacts
- Each row: avatar, name, last message preview, time, unread badge
- AppBar: app name + profile icon (→ Profile screen)
- Footer: online count indicator (e.g. "3 из 5 онлайн")
- Tapping a contact that was auto-discovered but has no chat → opens new direct chat

### Chat Screen
- Bubble layout: outgoing right (green), incoming left (white)
- Message status icons: no tick = queued, ✓ = sent locally, ✓✓ = delivered
- Attachment button (📎) → bottom sheet: Photo, Video, File
- Max visible message history: all stored in SQLite, lazy-loaded in chunks of 50
- Long-press message → Delete (local only)

### Profile Screen
- Edit name and avatar
- Show own UUID as QR code (for manual contact add)
- "Add contact by QR" scanner

### Contact Discovery
- Auto: devices on same Wi-Fi appear in "Discovered" section of chat list
- Manual: scan QR code from Profile screen of the other device

---

## Background & Notifications

### Android
- Foreground Service started on app launch via `flutter_foreground_task`
- Service keeps WebSocket server alive when app is backgrounded or closed
- Persistent status bar notification: "FamilyChat активен"
- Auto-restart on device reboot via `BOOT_COMPLETED` broadcast receiver
- New message → `flutter_local_notifications` push notification

### iOS
- No persistent background TCP server (platform restriction, no APNs server)
- App is fully functional when open or briefly backgrounded (~30s)
- When app is reopened → all pending messages delivered immediately
- Local notifications shown while app is active
- Acceptable trade-off for family use: open the app to receive

---

## Flutter Packages

| package | purpose |
|---|---|
| `multicast_dns` | mDNS peer discovery |
| `web_socket_channel` | WebSocket client + server |
| `flutter_foreground_task` | Android foreground service |
| `flutter_local_notifications` | local push notifications |
| `sqflite` | SQLite local database |
| `path_provider` | app documents directory |
| `image_picker` | pick photos/videos from gallery |
| `file_picker` | pick arbitrary files |
| `flutter_bloc` | BLoC state management |
| `uuid` | UUID generation |
| `shared_preferences` | persist own UUID and name |
| `qr_flutter` | render QR code |
| `mobile_scanner` | scan QR codes |

---

## Out of Scope

- Voice/video calls
- Message reactions or replies
- Read receipts (only delivery confirmation)
- End-to-end encryption (family LAN, low threat model)
- Message edit
- Cloud backup
- Internet/external network support
