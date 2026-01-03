### 💻 Software Architecture & Workflow

The software system of the Speak and Listen Glove handles gesture recognition, speech generation, haptic feedback, and secure administration. It is composed of a mobile application and a backend system.

### 📱 Mobile Application

The mobile application is developed using Flutter, enabling cross-platform support for both Android and iOS devices. It serves as the primary interface between the user and the smart glove.

Communication between the glove and the app is achieved using Bluetooth Low Energy (BLE). The glove continuously transmits data from five flex sensors, which are normalized into three discrete zones:

0 – Straight

1 – Bent

2 – Folded

### 🗣️ Talking Mode (Gesture → Speech)

In Talking Mode, the software follows the pipeline below:

Receives five flex sensor values via BLE.

Converts sensor values into zone representations.

Matches zone patterns with a predefined CSV-based gesture mapping.

If no match is found, an on-device TensorFlow Lite ML model predicts the gesture.

Recognized letters are passed to the WordBuilder module to form words and sentences.

The final text output is converted to audio using Text-to-Speech (TTS).

⚠️ No vibration motors are used in this mode.

### 🧏 Speaking Mode (Speech → Gesture Guidance)

In Speaking Mode, the system reverses the interaction flow:

The application listens to a speaker using Speech-to-Text (STT).

Recognized speech is broken down into individual letters.

Each letter is mapped to its expected finger zone pattern using the CSV mapping.

Expected zones are compared with live zones received from the glove.

If a finger’s zone does not match, the corresponding vibration motor is activated.

When the zones match, the vibration stops, guiding the user to correctly form the gesture.


