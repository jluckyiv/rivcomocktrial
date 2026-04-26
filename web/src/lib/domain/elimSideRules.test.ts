import { describe, expect, test } from 'vitest'
import {
	type MeetingHistory,
	type Trial,
	elimSide,
	elimSideAssignment,
	meetingHistory,
} from './elimSideRules'

type Team = { id: number; name: string }

const teamA: Team = { id: 1, name: 'Team A' }
const teamB: Team = { id: 2, name: 'Team B' }
const teamC: Team = { id: 3, name: 'Team C' }

function trialFor(prosecution: Team, defense: Team): Trial<Team> {
	return { prosecution, defense }
}

describe('ElimSideRules', () => {
	describe('meetingHistory', () => {
		test('no prior trials → FirstMeeting with mostRecentSide', () => {
			expect(meetingHistory(teamA, teamB, [], 'Prosecution')).toEqual<MeetingHistory>({
				kind: 'FirstMeeting',
				mostRecentSide: 'Prosecution',
			})
		})

		test('one trial where higher seed was Prosecution → Rematch { Prosecution }', () => {
			expect(
				meetingHistory(teamA, teamB, [trialFor(teamA, teamB)], 'Prosecution')
			).toEqual<MeetingHistory>({ kind: 'Rematch', priorSide: 'Prosecution' })
		})

		test('one trial where higher seed was Defense → Rematch { Defense }', () => {
			expect(
				meetingHistory(teamA, teamB, [trialFor(teamB, teamA)], 'Prosecution')
			).toEqual<MeetingHistory>({ kind: 'Rematch', priorSide: 'Defense' })
		})

		test('two trials → ThirdMeeting', () => {
			expect(
				meetingHistory(
					teamA,
					teamB,
					[trialFor(teamA, teamB), trialFor(teamB, teamA)],
					'Prosecution'
				)
			).toEqual<MeetingHistory>({ kind: 'ThirdMeeting' })
		})

		test('unrelated trials excluded', () => {
			expect(
				meetingHistory(teamA, teamB, [trialFor(teamA, teamC)], 'Prosecution')
			).toEqual<MeetingHistory>({ kind: 'FirstMeeting', mostRecentSide: 'Prosecution' })
		})
	})

	describe('elimSide', () => {
		test('FirstMeeting { Prosecution } → Ok Defense (flip)', () => {
			expect(
				elimSide({ kind: 'FirstMeeting', mostRecentSide: 'Prosecution' })
			).toEqual({ ok: true, value: 'Defense' })
		})

		test('FirstMeeting { Defense } → Ok Prosecution (flip)', () => {
			expect(
				elimSide({ kind: 'FirstMeeting', mostRecentSide: 'Defense' })
			).toEqual({ ok: true, value: 'Prosecution' })
		})

		test('Rematch { Prosecution } → Ok Defense (flip)', () => {
			expect(elimSide({ kind: 'Rematch', priorSide: 'Prosecution' })).toEqual({
				ok: true,
				value: 'Defense',
			})
		})

		test('Rematch { Defense } → Ok Prosecution (flip)', () => {
			expect(elimSide({ kind: 'Rematch', priorSide: 'Defense' })).toEqual({
				ok: true,
				value: 'Prosecution',
			})
		})

		test('ThirdMeeting → Err', () => {
			const result = elimSide({ kind: 'ThirdMeeting' })
			expect(result.ok).toBe(false)
		})
	})

	describe('elimSideAssignment', () => {
		test('FirstMeeting { Prosecution } → Ok [Defense, Prosecution]', () => {
			expect(
				elimSideAssignment({ kind: 'FirstMeeting', mostRecentSide: 'Prosecution' })
			).toEqual({ ok: true, value: ['Defense', 'Prosecution'] })
		})

		test('FirstMeeting { Defense } → Ok [Prosecution, Defense]', () => {
			expect(
				elimSideAssignment({ kind: 'FirstMeeting', mostRecentSide: 'Defense' })
			).toEqual({ ok: true, value: ['Prosecution', 'Defense'] })
		})

		test('ThirdMeeting → Err propagated', () => {
			const result = elimSideAssignment({ kind: 'ThirdMeeting' })
			expect(result.ok).toBe(false)
		})
	})

	describe('meetingHistory → elimSideAssignment end-to-end', () => {
		test('first meeting as Prosecution → assigned Defense for elim', () => {
			const history = meetingHistory(teamA, teamB, [], 'Prosecution')
			expect(elimSideAssignment(history)).toEqual({
				ok: true,
				value: ['Defense', 'Prosecution'],
			})
		})

		test('rematch after being Prosecution → assigned Defense for elim', () => {
			const history = meetingHistory(teamA, teamB, [trialFor(teamA, teamB)], 'Prosecution')
			expect(elimSideAssignment(history)).toEqual({
				ok: true,
				value: ['Defense', 'Prosecution'],
			})
		})

		test('third meeting → coin flip required', () => {
			const history = meetingHistory(
				teamA,
				teamB,
				[trialFor(teamA, teamB), trialFor(teamB, teamA)],
				'Prosecution'
			)
			const result = elimSideAssignment(history)
			expect(result.ok).toBe(false)
		})
	})
})
