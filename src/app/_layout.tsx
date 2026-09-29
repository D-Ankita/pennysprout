import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { useMemo } from 'react';
import { StyleSheet, Text, View } from 'react-native';

import { parseEnv, readBundledEnv } from '@/config/env';
import { colors } from '@/theme/colors';

export default function RootLayout() {
  const env = useMemo(() => parseEnv(readBundledEnv()), []);

  if (!env.ok) {
    return (
      <View style={styles.container} accessible accessibilityRole="alert">
        <Text style={styles.title}>Configuration error</Text>
        {env.issues.map((issue) => (
          <Text key={issue} style={styles.body}>
            {issue}
          </Text>
        ))}
      </View>
    );
  }

  return (
    <>
      <StatusBar style="dark" />
      <Stack
        screenOptions={{
          headerShown: false,
          contentStyle: { backgroundColor: colors.canvas },
        }}
      />
    </>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    gap: 8,
    padding: 16,
    backgroundColor: colors.canvas,
  },
  title: {
    fontSize: 20,
    lineHeight: 26,
    fontWeight: '600',
    color: colors.error,
  },
  body: {
    fontSize: 16,
    lineHeight: 24,
    color: colors.ink,
  },
});
