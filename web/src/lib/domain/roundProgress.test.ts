import { describe, expect, test } from 'vitest'
import { type TrialStatus, progressToString, roundProgress } from './roundProgress'

function trial(status: TrialStatus) {
	return { status }
}

describe('RoundProgress', () => {
	describe('roundProgress', () => {
		test('all AwaitingCheckIn → CheckInOpen', () => {
			expect(
				roundProgress([trial('AwaitingCheckIn'), trial('AwaitingCheckIn')])
			).toBe('CheckInOpen')
		})

		test('mixed AwaitingCheckIn + InProgress → CheckInOpen', () => {
			expect(
				roundProgress([trial('AwaitingCheckIn'), trial('InProgress')])
			).toBe('CheckInOpen')
		})

		test('all InProgress → AllTrialsStarted', () => {
			expect(roundProgress([trial('InProgress'), trial('InProgress')])).toBe('AllTrialsStarted')
		})

		test('mixed InProgress + Complete → AllTrialsStarted', () => {
			expect(roundProgress([trial('InProgress'), trial('Complete')])).toBe('AllTrialsStarted')
		})

		test('all Complete → AllTrialsComplete', () => {
			expect(roundProgress([trial('Complete'), trial('Complete')])).toBe('AllTrialsComplete')
		})

		test('mixed Complete + Verified → AllTrialsComplete', () => {
			expect(roundProgress([trial('Complete'), trial('Verified')])).toBe('AllTrialsComplete')
		})

		test('all Verified → FullyVerified', () => {
			expect(roundProgress([trial('Verified'), trial('Verified')])).toBe('FullyVerified')
		})

		test('empty list → FullyVerified (vacuous truth)', () => {
			expect(roundProgress([])).toBe('FullyVerified')
		})
	})

	describe('progressToString', () => {
		test('CheckInOpen', () => {
			expect(progressToString('CheckInOpen')).toBe('Check-In Open')
		})
		test('AllTrialsStarted', () => {
			expect(progressToString('AllTrialsStarted')).toBe('All Trials Started')
		})
		test('AllTrialsComplete', () => {
			expect(progressToString('AllTrialsComplete')).toBe('All Trials Complete')
		})
		test('FullyVerified', () => {
			expect(progressToString('FullyVerified')).toBe('Fully Verified')
		})
	})
})
