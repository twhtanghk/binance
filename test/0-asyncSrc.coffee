import {filter, zip, take, interval, concatMap, tap, Subject, from, map, combineLatest, mergeMap} from 'rxjs'

b = new Subject()
c = b
  .pipe filter (x) -> x % 2 == 1
  .pipe map (x) -> {x, src: 'c'}
d = b
  .pipe filter (x) -> x % 5 == 0
  .pipe map (x) -> {x, src: 'd'}

(combineLatest [c, d])
  .subscribe (x) -> console.log x
from [1..100]
  .subscribe b
