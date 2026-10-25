"""Adversarial configuration cases; no claim of game runtime verification."""
import copy
import unittest
from check import load, validate


class FidelityDataTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.original = load()

    def setUp(self):
        self.data = copy.deepcopy(self.original)

    def row(self, table, identity):
        return next(r for r in self.data[table] if r['id'] == identity)

    def rejected(self, fragment):
        self.assertTrue(any(fragment in e for e in validate(self.data)), validate(self.data))

    def test_authored_tables(self):
        self.assertEqual(validate(self.data), [])

    def test_missing_power_policy(self):
        self.data['intervention_policies'].pop(0)
        self.rejected('entry coverage')

    def test_new_content_requires_classification(self):
        self.data['powers'].append({'id': 'POWER_NEW'})
        self.rejected('entry coverage')

    def test_duplicate_branch_with_other_id(self):
        duplicate = dict(self.data['intervention_policies'][0], id='OTHER_ID')
        self.data['intervention_policies'].append(duplicate)
        self.rejected('duplicate content branch')

    def test_unknown_target_scope(self):
        self.row('intervention_policies', 'POWER_TRANSFER')['focus_scope'] = 'any'
        self.rejected('invalid focus')

    def test_single_endpoint_migration(self):
        self.row('intervention_policies', 'POWER_TRANSFER')['focus_scope'] = 'target'
        self.rejected('source_and_target')

    def test_deep_response_cannot_bypass_focus(self):
        self.row('intervention_policies', 'PRAYER_01_DEEP')['focus_scope'] = 'none'
        self.rejected('bypasses focus')

    def test_shallow_barrier_is_not_exempt(self):
        self.row('intervention_policies', 'PRAYER_09_SHALLOW')['focus_scope'] = 'none'
        self.rejected('bypasses focus')

    def test_loyalty_branch_reserves_member(self):
        self.row('intervention_policies', 'PRAYER_08_SHALLOW')['member_scope'] = 'none'
        self.rejected('member_scope must be nominees')

    def test_member_requires_participant(self):
        self.row('intervention_policies', 'POWER_APPOINT')['person_scope'] = 'none'
        self.rejected('enrollment without participants')

    def test_default_cannot_need_new_focus(self):
        self.row('intervention_policies', 'EVENT_11_B')['focus_scope'] = 'target'
        self.rejected('focus_scope must be none')

    def test_default_cannot_materialize_new_actor(self):
        self.row('intervention_policies', 'EVENT_03_B')['person_scope'] = 'participants'
        self.rejected('person_scope must be fixed')

    def test_background_economy_cannot_have_second_producer(self):
        self.row('simulation_responsibilities', 'economy')['background'] = 'abstract_due'
        self.rejected('duty coverage')

    def test_background_risk_cannot_pause(self):
        self.row('simulation_responsibilities', 'risk_selection')['background'] = 'abstract_due'
        self.rejected('duty coverage')

    def test_missing_duty(self):
        self.data['simulation_responsibilities'].pop()
        self.rejected('duty coverage')

    def test_capacity_must_fit_cross_domain_command(self):
        self.row('fidelity_parameters', 'focused_domain_limit')['value'] = '1'
        self.rejected('two-domain')

    def test_local_capacity_fits_roles(self):
        self.row('fidelity_parameters', 'local_actor_limit')['value'] = '1'
        self.rejected('institution roles')

    def test_active_and_identity_capacity_distinct(self):
        self.row('fidelity_parameters', 'bound_member_limit')['value'] = '144'
        self.rejected('persistent living')

    def test_invalid_values(self):
        for value in ('0', '-1', 'NaN', 'inf', '3.5', '03'):
            with self.subTest(value=value):
                self.row('fidelity_parameters', 'background_tick_interval')['value'] = value
                self.rejected('positive canonical integer')

    def test_unknown_parameter_not_silently_accepted(self):
        self.data['fidelity_parameters'].append(dict(self.data['fidelity_parameters'][0], id='another_budget'))
        self.rejected('parameter coverage')

    def test_unit_and_activation_are_typed(self):
        row = self.row('fidelity_parameters', 'focused_domain_limit')
        row['unit'], row['activation'] = 'card', 'implemented'
        self.rejected('invalid unit or activation')

    def test_no_second_budget_source(self):
        self.data['event_parameters'].append({'id': 'focused_domain_limit', 'value': '3'})
        self.rejected('duplicates existing owner')

    def test_candidates_fit_pool_and_single_actor_budget(self):
        self.row('fidelity_parameters', 'pending_candidate_limit')['value'] = '1'
        self.row('fidelity_parameters', 'candidate_actor_limit')['value'] = '13'
        self.rejected('candidate pool')
        self.rejected('temporary capacity')


if __name__ == '__main__':
    unittest.main()
