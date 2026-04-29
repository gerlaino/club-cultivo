import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia } from 'pinia'
import { createRouter, createMemoryHistory } from 'vue-router'
import App from '../App.vue'

describe('App', () => {
  it('mounts without errors', () => {
    const pinia = createPinia()
    const router = createRouter({
      history: createMemoryHistory(),
      routes: [{ path: '/', component: { template: '<div/>' } }],
    })
    const wrapper = mount(App, {
      global: { plugins: [pinia, router] },
    })
    expect(wrapper.exists()).toBe(true)
  })
})
