// Areas 7 to 9: the stateful flows, played on the real page.
import { genRounds } from './rounds.mjs';
import { genSideTargets, genSideSuggest, genSideRounds } from './side.mjs';
import { genHome } from './home.mjs';

export default [genRounds, genSideTargets, genSideSuggest, genSideRounds, genHome];
