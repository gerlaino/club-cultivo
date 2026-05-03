const DEV = import.meta.env.DEV

export const logger = {
  error: (msg, ...args) => { if (DEV) console.error(msg, ...args) },
  warn:  (msg, ...args) => { if (DEV) console.warn(msg, ...args)  },
  info:  (msg, ...args) => { if (DEV) console.info(msg, ...args)  },
  debug: (msg, ...args) => { if (DEV) console.debug(msg, ...args) },
}
