export type FeatureTone = 'primary' | 'danger'

export interface FeatureGroup {
  groupKey: string
  title: string
  description: string
  features: FeatureDefinition[]
}

export type FeatureDefinition = ActionFeatureDefinition | RangeFeatureDefinition

export interface FeatureBaseDefinition {
  featureKey: string
  title: string
  description: string
  mobileReady: boolean
}

export interface ActionFeatureDefinition extends FeatureBaseDefinition {
  control: {
    type: 'action'
    buttonText: string
    tone: FeatureTone
    confirmRequired: boolean
  }
}

export interface RangeFeatureDefinition extends FeatureBaseDefinition {
  control: {
    type: 'range'
    min: number
    max: number
    step: number
    unit: string
    actionText: string
  }
}

export interface FeatureSnapshot {
  volumeLevel: number
}

export type FeatureCommand =
  | { feature: 'shutdown' }
  | { feature: 'restart' }
  | { feature: 'test_notification' }
  | { feature: 'error_test' }
  | { feature: 'volume'; level: number }

export interface FeatureExecutionResult {
  featureKey: string
  message: string
  volumeLevel: number | null
}

export function isActionFeature(
  feature: FeatureDefinition,
): feature is ActionFeatureDefinition {
  return feature.control.type === 'action'
}

export function isRangeFeature(
  feature: FeatureDefinition,
): feature is RangeFeatureDefinition {
  return feature.control.type === 'range'
}
