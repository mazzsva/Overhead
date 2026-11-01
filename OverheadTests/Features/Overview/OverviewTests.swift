//
//  OverviewTests.swift
//  OverheadTests
//
//  Created by Lorenzo Mazzarotto on 04/10/26.
//

import ComposableArchitecture
import CustomDump
import Foundation
import Testing

@testable import Overhead

extension BaseSuite {
    @Suite
    @MainActor
    struct OverviewTests {
        @Test
        func theAnnualExpensesAddTheAnnualAmountOfEachActiveExpense() {
            let state = makeState(expenses: [expense(65, .monthly, id: 10), expense(1200, .yearly, id: 11), .phonePlan])

            expectNoDifference(state.annualExpenses, 1980)
        }

        @Test
        func theAnnualExpensesAreUnknownUntilTheExpensesLoad() {
            expectNoDifference(makeState(expenses: nil).annualExpenses, nil)
        }

        @Test
        func withoutActiveExpensesTheAnnualExpensesAreZero() {
            expectNoDifference(makeState(expenses: []).annualExpenses, 0)
            expectNoDifference(makeState(expenses: [.phonePlan]).annualExpenses, 0)
        }

        @Test
        func theActiveExpenseCountSkipsPausedExpenses() {
            expectNoDifference(makeState(expenses: [.rent, .gym, .phonePlan]).activeExpenseCount, 2)
            expectNoDifference(makeState(expenses: nil).activeExpenseCount, nil)
        }

        @Test(
            arguments: [
                (Overview.BudgetStatus.failed, Overview.IncomeStatus.failed),
                (.loaded(nil), .missing),
                (.loading, .loading),
                (.offline, .offline),
            ]
        )
        func withoutABudgetTheContentShowsTheExpenses(
            budgetStatus: Overview.BudgetStatus,
            incomeStatus: Overview.IncomeStatus
        ) {
            expectNoDifference(
                makeState(budgetStatus, expenses: Expense.mocks).content,
                .expensesOnly(amount: 990, income: incomeStatus)
            )
        }

        @Test
        func aLoadedBudgetShowsTheSummary() {
            expectNoDifference(
                makeState(.loaded(.mock), expenses: Expense.mocks).content,
                .summary(Overview.Breakdown(annualExpenses: 11880, budget: .mock))
            )
        }

        @Test(arguments: [Overview.BudgetStatus.failed, .loaded(nil), .loaded(.mock), .loading, .offline])
        func withoutExpensesTheContentIsUnavailable(budgetStatus: Overview.BudgetStatus) {
            expectNoDifference(makeState(budgetStatus, expenses: nil).content, nil)
        }

        @Test
        func withoutIncomeTheContentShowsTheMonthlyExpenses() {
            let state = makeState(.loaded(nil), expenses: [expense(1300, .yearly, id: 10)])

            expectNoDifference(state.content, .expensesOnly(amount: 108, income: .missing))
        }

        @Test
        func theBreakdownSplitsTheIncome() {
            let breakdown = Overview.Breakdown(annualExpenses: 11880, budget: .mock)

            expectNoDifference(breakdown.income, 3000)
            expectNoDifference(breakdown.expenses, .init(amount: 990, share: percent(33)))
            expectNoDifference(breakdown.savings, .init(amount: 450, share: percent(15)))
            expectNoDifference(breakdown.committed, .init(amount: 1440, share: percent(48)))
            expectNoDifference(breakdown.available, .init(amount: 1560, share: percent(52)))
            #expect(!breakdown.isOverBudget)
        }

        @Test
        func theBreakdownRoundsEachPartOnceAndKeepsTheSum() throws {
            let budget = try #require(Budget(income: 3200, investment: 450))
            let breakdown = Overview.Breakdown(annualExpenses: 14091, budget: budget)

            expectNoDifference(breakdown.income, 3200)
            expectNoDifference(breakdown.expenses.amount, 1174)
            expectNoDifference(breakdown.savings?.amount, 450)
            expectNoDifference(breakdown.committed.amount, 1624)
            expectNoDifference(breakdown.available.amount, 1576)
        }

        @Test
        func aBudgetDoesNotGoOverWhenOnlyTheRoundingDoes() throws {
            let budget = try #require(Budget(income: 2000, investment: 1000))
            let breakdown = Overview.Breakdown(annualExpenses: 11999, budget: budget)

            #expect(!breakdown.isOverBudget)
            #expect(breakdown.available.amount >= 0)
            expectNoDifference(breakdown.availableShareLabel, .lessThanOnePercent)
        }

        @Test
        func tinyPartsShowAsLessThanOnePercent() throws {
            let budget = try #require(Budget(income: 10000, investment: 5))
            let breakdown = Overview.Breakdown(annualExpenses: 12, budget: budget)

            #expect(breakdown.hasExpenses)
            expectNoDifference(breakdown.expensesShareLabel, .lessThanOnePercent)
            expectNoDifference(breakdown.savingsShareLabel, .lessThanOnePercent)
            expectNoDifference(breakdown.committedShareLabel, .lessThanOnePercent)
            expectNoDifference(breakdown.availableShareLabel, .moreThanNinetyNinePercent)
        }

        @Test
        func withoutCostsTheIncomeIsAllAvailable() throws {
            let budget = try #require(Budget(income: 3000, investment: nil))
            let breakdown = Overview.Breakdown(annualExpenses: 0, budget: budget)

            #expect(!breakdown.hasExpenses)
            expectNoDifference(breakdown.expensesShareLabel, .percent(0))
            expectNoDifference(breakdown.availableShareLabel, .percent(1))
        }

        @Test
        func costsEqualToTheIncomeAreFullyCommitted() throws {
            let budget = try #require(Budget(income: 3000, investment: nil))
            let breakdown = Overview.Breakdown(annualExpenses: 36000, budget: budget)

            #expect(!breakdown.isOverBudget)
            expectNoDifference(breakdown.available.amount, 0)
            expectNoDifference(breakdown.committedShareLabel, .percent(1))
            expectNoDifference(breakdown.availableShareLabel, .percent(0))
        }

        @Test
        func roundedSharesThatReachTheWholeStillShowAFullyCommittedBudget() throws {
            let budget = try #require(Budget(income: 1000, investment: 495))
            let breakdown = Overview.Breakdown(annualExpenses: 6060, budget: budget)

            expectNoDifference(breakdown.committed.share, percent(101))
            expectNoDifference(breakdown.committedShareLabel, .percent(1))
        }

        @Test
        func roundedSharesThatStayAtTheWholeStillShowAnOverBudget() throws {
            let budget = try #require(Budget(income: 1000, investment: nil))
            let breakdown = Overview.Breakdown(annualExpenses: 12001, budget: budget)

            expectNoDifference(breakdown.committed.share, 1)
            #expect(breakdown.isOverBudget)
            expectNoDifference(breakdown.committedShareLabel, .moreThanOneHundredPercent)
            expectNoDifference(breakdown.availableShareLabel, .lessThanOnePercent)
        }

        @Test
        func withoutExpensesTheCommittedShareIsTheSavings() {
            let breakdown = Overview.Breakdown(annualExpenses: 0, budget: .mock)

            expectNoDifference(breakdown.committedShareLabel, .percent(percent(15)))
        }

        @Test
        func expensesAboveTheIncomeShowSharesAboveTheWhole() throws {
            let budget = try #require(Budget(income: 1000, investment: 300))
            let breakdown = Overview.Breakdown(annualExpenses: 14400, budget: budget)

            expectNoDifference(breakdown.available.amount, -500)
            expectNoDifference(breakdown.committedShareLabel, .percent(percent(150)))
            expectNoDifference(breakdown.availableShareLabel, .percent(percent(50)))
        }

        @Test
        func theSharesAlwaysAddUpToTheWhole() throws {
            let budget = try #require(Budget(income: 3000, investment: 1001))
            let breakdown = Overview.Breakdown(
                annualExpenses: 12006, budget: budget)

            expectNoDifference(breakdown.expenses.share, percent(33))
            expectNoDifference(breakdown.savings?.share, percent(33))
            expectNoDifference(breakdown.available.share, percent(34))
            expectNoDifference(breakdown.committed.share, percent(66))
        }

        @Test
        func aBudgetWithoutSavingsHasNoSavingsLine() throws {
            let budget = try #require(Budget(income: 3000, investment: nil))
            let breakdown = Overview.Breakdown(annualExpenses: 12000, budget: budget)

            expectNoDifference(breakdown.savings, nil)
            expectNoDifference(breakdown.committed, .init(amount: 1000, share: percent(33)))
            expectNoDifference(breakdown.available, .init(amount: 2000, share: percent(67)))
        }

        @Test
        func costsAboveTheIncomeMakeTheAvailableAmountNegative() throws {
            let budget = try #require(Budget(income: 900, investment: 100))
            let breakdown = Overview.Breakdown(annualExpenses: 12000, budget: budget)

            expectNoDifference(breakdown.available.amount, -200)
            #expect(breakdown.isOverBudget)
        }

        @Test
        func theTaskObservesTheBudget() async {
            let budget = AsyncThrowingStream<BudgetSnapshot, any Error>.makeStream()

            let store = TestStore(initialState: makeState()) {
                Overview()
            } withDependencies: {
                $0.budgetClient.budget = { uid in
                    expectNoDifference(uid, User.mock.uid)
                    return budget.stream
                }
            }

            let task = await store.send(.task)

            budget.continuation.yield(.known(nil))
            await store.receive(\.budgetUpdated) {
                $0.budgetStatus = .loaded(nil)
            }

            budget.continuation.yield(.known(.mock))
            await store.receive(\.budgetUpdated) {
                $0.budgetStatus = .loaded(.mock)
            }

            await task.cancel()
        }

        @Test
        func anUnknownMissingBudgetBeforeAnyLoadMeansOffline() async {
            let store = TestStore(initialState: makeState()) {
                Overview()
            }

            await store.send(.budgetUpdated(.unknown)) {
                $0.budgetStatus = .offline
            }
            await store.send(.budgetUpdated(.known(nil))) {
                $0.budgetStatus = .loaded(nil)
            }
        }

        @Test
        func aCachedBudgetLoadsWhileOffline() async {
            let store = TestStore(initialState: makeState()) {
                Overview()
            }

            await store.send(.budgetUpdated(.known(.mock))) {
                $0.budgetStatus = .loaded(.mock)
            }
        }

        @Test
        func aBudgetRemovedOfflineDisappearsAtOnce() async {
            let store = TestStore(initialState: makeState(.loaded(.mock))) {
                Overview()
            }

            await store.send(.budgetUpdated(.known(nil))) {
                $0.budgetStatus = .loaded(nil)
            }
        }

        @Test
        func anUnknownMissingBudgetKeepsTheLoadedBudget() async {
            let store = TestStore(initialState: makeState(.loaded(.mock))) {
                Overview()
            }

            await store.send(.budgetUpdated(.unknown))
        }

        @Test
        func aFailedFirstLoadShowsTheFailureAndRetriesAfterFiveSeconds() async {
            let clock = TestClock()
            let attempts = LockIsolated(0)

            let store = TestStore(initialState: makeState()) {
                Overview()
            } withDependencies: {
                $0.budgetClient.budget = { _ in
                    let attempt = attempts.withValue {
                        $0 += 1
                        return $0
                    }
                    return AsyncThrowingStream { continuation in
                        if attempt == 1 {
                            continuation.finish(throwing: BudgetFailure())
                        } else {
                            continuation.yield(.known(.mock))
                            continuation.finish()
                        }
                    }
                }
                $0.continuousClock = clock
            }

            await store.send(.task)
            await store.receive(\.budgetStreamFailed) {
                $0.budgetStatus = .failed
            }

            await clock.advance(by: .seconds(4))
            expectNoDifference(attempts.value, 1)

            await clock.advance(by: .seconds(1))
            await store.receive(\.budgetUpdated) {
                $0.budgetStatus = .loaded(.mock)
            }
            await store.finish()
            expectNoDifference(attempts.value, 2)
        }

        @Test
        func aFailedStreamKeepsTheBudget() async {
            let clock = TestClock()
            let attempts = LockIsolated(0)

            let store = TestStore(initialState: makeState(.loaded(.mock))) {
                Overview()
            } withDependencies: {
                $0.budgetClient.budget = { _ in
                    let attempt = attempts.withValue {
                        $0 += 1
                        return $0
                    }
                    return AsyncThrowingStream { continuation in
                        attempt == 1 ? continuation.finish(throwing: BudgetFailure()) : continuation.finish()
                    }
                }
                $0.continuousClock = clock
            }

            await store.send(.task)
            await store.receive(\.budgetStreamFailed)
            await clock.advance(by: .seconds(5))
            await store.finish()
            expectNoDifference(attempts.value, 2)
        }

        @Test
        func cancellingTheTaskStopsTheRetry() async {
            let clock = TestClock()
            let attempts = LockIsolated(0)

            let store = TestStore(initialState: makeState()) {
                Overview()
            } withDependencies: {
                $0.budgetClient.budget = { _ in
                    attempts.withValue { $0 += 1 }
                    return AsyncThrowingStream { continuation in
                        continuation.finish(throwing: BudgetFailure())
                    }
                }
                $0.continuousClock = clock
            }

            let task = await store.send(.task)
            await store.receive(\.budgetStreamFailed) {
                $0.budgetStatus = .failed
            }
            await task.cancel()
            await clock.advance(by: .seconds(5))
            expectNoDifference(attempts.value, 1)
        }

        @Test
        func theExpensesTileAsksToShowTheExpenses() async {
            let store = TestStore(initialState: makeState()) {
                Overview()
            }

            await store.send(.expensesButtonTapped)
            await store.receive(\.delegate.didSelectExpenses)
        }

        @Test
        func theSettingsButtonSelectsTheSettings() async {
            let store = TestStore(initialState: makeState()) {
                Overview()
            }

            await store.send(.settingsButtonTapped)
            await store.receive(\.delegate.didSelectSettings)
        }

        @Test
        func theIncomeTileWithoutIncomeOpensAnEmptyForm() async {
            let store = TestStore(initialState: makeState(.loaded(nil))) {
                Overview()
            }

            await store.send(.incomeTileTapped) {
                $0.destination = .incomeForm(IncomeForm.State(budget: nil))
            }
        }

        @Test(arguments: [Overview.BudgetStatus.failed, .loading, .offline])
        func theIncomeTileWaitsForTheBudget(budgetStatus: Overview.BudgetStatus) async {
            let store = TestStore(initialState: makeState(budgetStatus)) {
                Overview()
            }

            await store.send(.incomeTileTapped)
        }

        @Test
        func eachTileOpensItsOwnForm() async {
            let store = TestStore(initialState: makeState(.loaded(.mock))) {
                Overview()
            }

            await store.send(.incomeTileTapped) {
                $0.destination = .incomeForm(IncomeForm.State(budget: .mock))
            }
            await store.send(.destination(.dismiss)) {
                $0.destination = nil
            }
            await store.send(.savingsTileTapped) {
                $0.destination = .investmentForm(InvestmentForm.State(income: 3000, investment: 450))
            }
        }

        @Test
        func theSavingsNeedAnIncome() async {
            let store = TestStore(initialState: makeState(.loaded(nil))) {
                Overview()
            }

            await store.send(.savingsTileTapped)
        }

        @Test
        func theSavingsTileWithoutSavingsOpensAnEmptyForm() async throws {
            let budget = try #require(Budget(income: 3000, investment: nil))
            let store = TestStore(initialState: makeState(.loaded(budget))) {
                Overview()
            }

            await store.send(.savingsTileTapped) {
                $0.destination = .investmentForm(InvestmentForm.State(income: 3000, investment: nil))
            }
        }

        @Test
        func aSecondTapDoesNotReplaceTheOpenForm() async {
            let store = TestStore(initialState: makeState(.loaded(.mock))) {
                Overview()
            }

            await store.send(.incomeTileTapped) {
                $0.destination = .incomeForm(IncomeForm.State(budget: .mock))
            }
            await store.send(.savingsTileTapped)
            await store.send(.incomeTileTapped)
        }

        @Test
        func anOpenFormFollowsTheBudget() async throws {
            var state = makeState(.loaded(.mock))
            state.destination = .incomeForm(IncomeForm.State(budget: .mock))
            let store = TestStore(initialState: state) {
                Overview()
            }

            let raised = try #require(Budget(income: 3000, investment: 600))
            await store.send(.budgetUpdated(.known(raised))) {
                $0.budgetStatus = .loaded(raised)
                $0.destination?.modify(\.incomeForm) { $0.investment = 600 }
            }

            await store.send(.destination(.dismiss)) {
                $0.destination = nil
            }
            await store.send(.savingsTileTapped) {
                $0.destination = .investmentForm(InvestmentForm.State(income: 3000, investment: 600))
            }
            let promoted = try #require(Budget(income: 4000, investment: 600))
            await store.send(.budgetUpdated(.known(promoted))) {
                $0.budgetStatus = .loaded(promoted)
                $0.destination?.modify(\.investmentForm) { $0.income = 4000 }
            }
            await store.send(.budgetUpdated(.known(nil))) {
                $0.budgetStatus = .loaded(nil)
                $0.destination = nil
            }
        }

        @Test
        func anOpenIncomeFormStaysOpenWhenTheBudgetIsRemoved() async {
            var state = makeState(.loaded(.mock))
            state.destination = .incomeForm(IncomeForm.State(budget: .mock))
            let store = TestStore(initialState: state) {
                Overview()
            }

            await store.send(.budgetUpdated(.known(nil))) {
                $0.budgetStatus = .loaded(nil)
                $0.destination?.modify(\.incomeForm) { $0.investment = nil }
            }
        }

        @Test
        func savingTheIncomeWritesOnlyTheIncome() async {
            var state = makeState(.loaded(.mock))
            state.destination = .incomeForm(IncomeForm.State(budget: .mock))
            let calls = LockIsolated<[Call]>([])

            let store = TestStore(initialState: state) {
                Overview()
            } withDependencies: {
                $0.budgetClient.saveIncome = { income, removingInvestment, uid in
                    calls.withValue { $0.append(.saveIncome(income, removingInvestment: removingInvestment, uid: uid)) }
                }
                $0.hapticsClient.success = { calls.withValue { $0.append(.success) } }
            }

            await store.send(.destination(.presented(.incomeForm(.delegate(.didSubmit(3500)))))) {
                $0.destination = nil
            }
            await store.finish()
            expectNoDifference(
                Set(calls.value), [.saveIncome(3500, removingInvestment: false, uid: User.mock.uid), .success])
        }

        @Test
        func savingTheIncomeCanRemoveTheInvestmentInTheSameWrite() async {
            var state = makeState(.loaded(.mock))
            state.destination = .incomeForm(IncomeForm.State(budget: .mock))
            let calls = LockIsolated<[Call]>([])

            let store = TestStore(initialState: state) {
                Overview()
            } withDependencies: {
                $0.budgetClient.saveIncome = { income, removingInvestment, uid in
                    calls.withValue { $0.append(.saveIncome(income, removingInvestment: removingInvestment, uid: uid)) }
                }
                $0.hapticsClient.success = { calls.withValue { $0.append(.success) } }
            }

            await store.send(.destination(.presented(.incomeForm(.delegate(.didSubmitRemovingInvestment(400)))))) {
                $0.destination = nil
            }
            await store.finish()
            expectNoDifference(
                Set(calls.value), [.saveIncome(400, removingInvestment: true, uid: User.mock.uid), .success])
        }

        @Test
        func savingTheInvestmentWritesOnlyTheInvestment() async {
            var state = makeState(.loaded(.mock))
            state.destination = .investmentForm(InvestmentForm.State(income: 3000, investment: 450))
            let calls = LockIsolated<[Call]>([])

            let store = TestStore(initialState: state) {
                Overview()
            } withDependencies: {
                $0.budgetClient.saveInvestment = { investment, uid in
                    calls.withValue { $0.append(.saveInvestment(investment, uid: uid)) }
                }
                $0.hapticsClient.success = { calls.withValue { $0.append(.success) } }
            }

            await store.send(.destination(.presented(.investmentForm(.delegate(.didSubmit(300)))))) {
                $0.destination = nil
            }
            await store.finish()
            expectNoDifference(Set(calls.value), [.saveInvestment(300, uid: User.mock.uid), .success])
        }

        @Test
        func removingTheInvestmentKeepsTheIncome() async {
            var state = makeState(.loaded(.mock))
            state.destination = .investmentForm(InvestmentForm.State(income: 3000, investment: 450))
            let calls = LockIsolated<[Call]>([])

            let store = TestStore(initialState: state) {
                Overview()
            } withDependencies: {
                $0.budgetClient.removeInvestment = { uid in
                    calls.withValue { $0.append(.removeInvestment(uid: uid)) }
                }
                $0.hapticsClient.warning = { calls.withValue { $0.append(.warning) } }
            }

            await store.send(.destination(.presented(.investmentForm(.delegate(.didRemove))))) {
                $0.destination = nil
            }
            await store.finish()
            expectNoDifference(Set(calls.value), [.removeInvestment(uid: User.mock.uid), .warning])
        }

        @Test
        func removingTheIncomeRemovesOnlyTheBudget() async {
            var state = makeState(.loaded(.mock))
            state.destination = .incomeForm(IncomeForm.State(budget: .mock))
            let calls = LockIsolated<[Call]>([])

            let store = TestStore(initialState: state) {
                Overview()
            } withDependencies: {
                $0.budgetClient.removeIncome = { uid in
                    calls.withValue { $0.append(.removeIncome(uid: uid)) }
                }
                $0.hapticsClient.warning = { calls.withValue { $0.append(.warning) } }
            }

            await store.send(.destination(.presented(.incomeForm(.delegate(.didRemove))))) {
                $0.destination = nil
            }
            await store.finish()
            expectNoDifference(Set(calls.value), [.removeIncome(uid: User.mock.uid), .warning])
        }

        @Test
        func aFailedChangeTellsTheParentWhichChangeFailed() async {
            await expectFailure(
                of: .destination(.presented(.incomeForm(.delegate(.didRemove)))),
                in: .incomeForm(IncomeForm.State(budget: .mock)),
                reports: .removeIncome
            )
            await expectFailure(
                of: .destination(.presented(.incomeForm(.delegate(.didSubmit(3500))))),
                in: .incomeForm(IncomeForm.State(budget: .mock)),
                reports: .saveIncome
            )
            await expectFailure(
                of: .destination(.presented(.investmentForm(.delegate(.didRemove)))),
                in: .investmentForm(InvestmentForm.State(income: 3000, investment: 450)),
                reports: .removeInvestments
            )
            await expectFailure(
                of: .destination(.presented(.investmentForm(.delegate(.didSubmit(300))))),
                in: .investmentForm(InvestmentForm.State(income: 3000, investment: 450)),
                reports: .saveInvestments
            )
        }

        private func expectFailure(
            of action: Overview.Action,
            in destination: Overview.Destination.State,
            reports change: Overview.BudgetChange
        ) async {
            var state = makeState(.loaded(.mock))
            state.destination = destination

            let store = TestStore(initialState: state) {
                Overview()
            } withDependencies: {
                $0.budgetClient.removeIncome = { _ in throw BudgetFailure() }
                $0.budgetClient.removeInvestment = { _ in throw BudgetFailure() }
                $0.budgetClient.saveIncome = { _, _, _ in throw BudgetFailure() }
                $0.budgetClient.saveInvestment = { _, _ in throw BudgetFailure() }
                $0.hapticsClient.success = {}
                $0.hapticsClient.warning = {}
            }

            await store.send(action) {
                $0.destination = nil
            }
            await store.receive(\.delegate.didFailToChangeBudget, change)
            await store.finish()
        }

        private func makeState(
            _ budgetStatus: Overview.BudgetStatus = .loading,
            expenses: [Expense]? = nil
        ) -> Overview.State {
            Overview.State(
                budgetStatus: budgetStatus,
                expenses: SharedReader(value: expenses.map { IdentifiedArray(uniqueElements: $0) }),
                user: .mock
            )
        }

        private func expense(_ amount: Amount, _ billingCycle: BillingCycle, id: Int) -> Expense {
            Expense(
                amount: amount,
                billingCycle: billingCycle,
                createdAt: Date(timeIntervalSince1970: 1_750_000_000),
                id: UUID(id),
                isActive: true,
                name: ExpenseName(stringLiteral: billingCycle.rawValue)
            )
        }

        private func percent(_ value: Int) -> Decimal {
            Decimal(value) / 100
        }

        private enum Call: Hashable {
            case removeIncome(uid: String)
            case removeInvestment(uid: String)
            case saveIncome(Amount, removingInvestment: Bool, uid: String)
            case saveInvestment(Amount, uid: String)
            case success
            case warning
        }

        private struct BudgetFailure: Error {}
    }
}
