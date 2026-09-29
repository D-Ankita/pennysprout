import { renderRouter, screen } from 'expo-router/testing-library';

import * as envModule from '@/config/env';

import RootLayout from '@/app/_layout';
import Index from '@/app/index';

describe('app shell', () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('renders the home placeholder when configuration is valid', async () => {
    jest.spyOn(envModule, 'readBundledEnv').mockReturnValue({
      EXPO_PUBLIC_APP_ENV: 'local',
      EXPO_PUBLIC_SUPABASE_URL: 'http://127.0.0.1:54321',
      EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_example',
    });

    await renderRouter({ _layout: RootLayout, index: Index });

    expect(screen.getByRole('header', { name: 'PennySprout' })).toBeOnTheScreen();
    expect(screen.getByText('Small habits. Smart money.')).toBeOnTheScreen();
  });

  it('blocks the app with a configuration error when variables are missing', async () => {
    jest.spyOn(envModule, 'readBundledEnv').mockReturnValue({});

    await renderRouter({ _layout: RootLayout, index: Index });

    expect(screen.getByRole('alert')).toBeOnTheScreen();
    expect(screen.getByText('Configuration error')).toBeOnTheScreen();
    expect(screen.queryByText('PennySprout')).not.toBeOnTheScreen();
  });
});
