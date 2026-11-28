// File Location: labs/lab_02_multi_container_compose/frontend/src/App.test.jsx

import { render, screen } from '@testing-library/react';
import { expect, test, vi } from 'vitest';
import axios from 'axios';
import App from './App';

vi.mock('axios');

test('renders the heading and the users returned by the API', async () => {
  axios.get.mockImplementation((url) =>
    Promise.resolve(
      url.endsWith('/api/users')
        ? { data: { users: [{ id: 1, username: 'alice', email: 'alice@example.com' }] } }
        : { data: { status: 'healthy' } }
    )
  );

  render(<App />);

  expect(screen.getByText(/DockVerseHub - Full Stack App/)).toBeInTheDocument();
  expect(await screen.findByText(/alice@example.com/)).toBeInTheDocument();
});
