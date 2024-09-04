import { Camera, useCameraPermissions } from "expo-camera"
import React, { useState, useEffect, useRef } from "react"
import * as Haptics from "expo-haptics"
import * as Localization from "expo-localization"
import { evaluate } from "mathjs"
import TesseractOcr, { LANG_ENGLISH, LEVEL_SYMBOL } from "react-native-tesseract-ocr"

import { Button, StyleSheet, Text, TouchableOpacity, View } from "react-native"

export default () => {
    const [hasPermission, setHasPermission] = useState(null)
    const [result, setResult] = useState("99")
    const cameraRef = useRef(null) // Reference to the camera

    useEffect(async () => {
        const { status } = await Camera.requestCameraPermissionsAsync()
        setHasPermission(status === "granted")
    }, [])

    if (hasPermission === null) {
        // Camera permissions are still loading
        return <View />
    }

    if (hasPermission === false) {
        // Camera permissions are not granted yet
        return (
            <View style={styles.container}>
                <Text style={{ textAlign: "center" }}>We need your permission to show the camera</Text>
                <Button onPress={() => Camera.requestCameraPermissionsAsync()} title="grant permission" />
            </View>
        )
    }

    const captureImage = async () => {
        if (cameraRef.current) {
            const photo = await cameraRef.current.takePictureAsync()
            console.log(photo.uri)

            const tessOptions = { level: LEVEL_SYMBOL }
            const recognizedText = await TesseractOcr.recognizeTokens(imageSource, LANG_ENGLISH, tessOptions)

            setText(recognizedText)

            Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success)
        }
    }

    return (
        <View style={styles.container}>
            <Camera style={styles.camera} type={Camera.Constants.Type.back} ref={cameraRef}>
                <View style={styles.buttonContainer}>
                    <TouchableOpacity style={styles.button} onPress={captureImage}>
                        <Text style={styles.text}>Take picture</Text>
                    </TouchableOpacity>
                    <Text style={styles.text}>{result}</Text>
                </View>
            </Camera>
        </View>
    )
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
        width: "100%",
        justifyContent: "center"
    },
    camera: {
        flex: 1
    },
    buttonContainer: {
        flex: 1,
        flexDirection: "row",
        backgroundColor: "transparent",
        margin: 64
    },
    button: {
        flex: 1,
        alignSelf: "flex-end",
        alignItems: "center"
    },
    text: {
        fontSize: 24,
        fontWeight: "bold",
        color: "white"
    }
})
