const { askForFoldersAccess, getAuthStatus } = require('../index')

describe('node-mac-permissions', () => {
  describe('getAuthStatus()', () => {
    it('should throw on invalid types', () => {
      expect(() => {
        getAuthStatus('bad-type')
      }).toThrowError(/bad-type is not a valid type/)
    })

    it('should return a string', () => {
      const types = [
        'accessibility',
        'bluetooth',
        'calendar',
        'camera',
        'contacts',
        'full-disk-access',
        'input-monitoring',
        'location',
        'microphone',
        'music-library',
        'photos-add-only',
        'photos-read-write',
        'reminders',
        'speech-recognition',
        'screen',
      ]

      const statuses = ['not determined', 'denied', 'authorized', 'restricted']
      for (const type of types) {
        const status = getAuthStatus(type)
        expect(statuses).toContain(status)
      }
    })
  })

  describe('askForFoldersAccess()', () => {
    it('should throw on invalid types', () => {
      expect(() => {
        askForFoldersAccess('bad-type')
      }).toThrowError(/bad-type is not a valid protected folder/)
    })
  })
})
