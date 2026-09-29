import { StyleSheet, Text, View } from 'react-native';

import { colors } from '@/theme/colors';

// Phase 0 placeholder. Role navigation arrives with the authentication foundation.
export default function Index() {
  return (
    <View style={styles.container}>
      <Text style={styles.title} accessibilityRole="header">
        PennySprout
      </Text>
      <Text style={styles.body}>Small habits. Smart money.</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    padding: 16,
    backgroundColor: colors.canvas,
  },
  title: {
    fontSize: 32,
    lineHeight: 38,
    fontWeight: '700',
    color: colors.ink,
  },
  body: {
    fontSize: 16,
    lineHeight: 24,
    color: colors.inkMuted,
  },
});
