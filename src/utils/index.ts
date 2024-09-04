import * as Haptics from "expo-haptics"

export const hapticFeedback = () => Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light)
export const hapticFeedbackSwitch = () => setTimeout(() => Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Heavy), 50)
export const hapticSuccess = () => Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success)
