import { describe, expect, test } from 'vitest'
import {
	type ActiveTrialStatus,
	type ScorerStatus,
	completeTrial,
	verifyTrial,
} from './trialClosure'

function tracking(scorerStatus: ScorerStatus) {
	return { scorerStatus }
}

function activeTrial(status: ActiveTrialStatus) {
	return { status }
}

describe('TrialClosure', () => {
	describe('completeTrial', () => {
		test('all submitted + InProgress → Ok Complete', () => {
			const result = completeTrial(tracking('AwaitingVerification'), activeTrial('InProgress'))
			expect(result.ok).toBe(true)
			if (result.ok) expect(result.value.status).toBe('Complete')
		})

		test('AwaitingSubmissions + InProgress → Err', () => {
			const result = completeTrial(tracking('AwaitingSubmissions'), activeTrial('InProgress'))
			expect(result.ok).toBe(false)
		})

		test('AwaitingCheckIn status → Err', () => {
			const result = completeTrial(
				tracking('AwaitingVerification'),
				activeTrial('AwaitingCheckIn')
			)
			expect(result.ok).toBe(false)
		})

		test('Complete status → Err', () => {
			const result = completeTrial(tracking('AwaitingVerification'), activeTrial('Complete'))
			expect(result.ok).toBe(false)
		})

		test('Verified status → Err', () => {
			const result = completeTrial(tracking('AwaitingVerification'), activeTrial('Verified'))
			expect(result.ok).toBe(false)
		})

		test('both ballot and status errors → Err', () => {
			const result = completeTrial(
				tracking('AwaitingSubmissions'),
				activeTrial('AwaitingCheckIn')
			)
			expect(result.ok).toBe(false)
		})
	})

	describe('verifyTrial', () => {
		test('AllVerified + Complete → Ok Verified', () => {
			const result = verifyTrial(tracking('AllVerified'), activeTrial('Complete'))
			expect(result.ok).toBe(true)
			if (result.ok) expect(result.value.status).toBe('Verified')
		})

		test('AwaitingVerification + Complete → Err', () => {
			const result = verifyTrial(tracking('AwaitingVerification'), activeTrial('Complete'))
			expect(result.ok).toBe(false)
		})

		test('AwaitingSubmissions + Complete → Err', () => {
			const result = verifyTrial(tracking('AwaitingSubmissions'), activeTrial('Complete'))
			expect(result.ok).toBe(false)
		})

		test('AllVerified + InProgress → Err', () => {
			const result = verifyTrial(tracking('AllVerified'), activeTrial('InProgress'))
			expect(result.ok).toBe(false)
		})
	})

	describe('integration', () => {
		test('full lifecycle: complete then verify', () => {
			const t = tracking('AllVerified')
			const completeResult = completeTrial(t, activeTrial('InProgress'))
			expect(completeResult.ok).toBe(true)
			if (!completeResult.ok) return
			const verifyResult = verifyTrial(t, completeResult.value)
			expect(verifyResult.ok).toBe(true)
			if (verifyResult.ok) expect(verifyResult.value.status).toBe('Verified')
		})

		test('correction round-trip: verify → reopen → re-verify', () => {
			const t = tracking('AllVerified')
			const completeResult = completeTrial(t, activeTrial('InProgress'))
			expect(completeResult.ok).toBe(true)
			if (!completeResult.ok) return
			const verifyResult = verifyTrial(t, completeResult.value)
			expect(verifyResult.ok).toBe(true)
			if (!verifyResult.ok) return
			// reopen: Verified → Complete
			const reopened = activeTrial('Complete')
			const reVerify = verifyTrial(t, reopened)
			expect(reVerify.ok).toBe(true)
			if (reVerify.ok) expect(reVerify.value.status).toBe('Verified')
		})

		test('complete with partial submissions → Err', () => {
			const result = completeTrial(tracking('AwaitingSubmissions'), activeTrial('InProgress'))
			expect(result.ok).toBe(false)
		})

		test('verify with partial verifications → Err', () => {
			const result = verifyTrial(tracking('AwaitingVerification'), activeTrial('Complete'))
			expect(result.ok).toBe(false)
		})
	})
})
