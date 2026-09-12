local Timeline = require("../TAS/PLAYER/timeline")
local Buffer = require("../TAS/CREATOR/recording-buffer")
local frames = {{time=0, id="first"}, {time=1, id="middle"}, {time=2, id="last"}}
local a, b, alpha, cursor, finished = Timeline.sample(frames, 0)
assert(a.id=="first" and b.id=="middle" and alpha==0 and not finished)
a, b, alpha, cursor, finished = Timeline.sample(frames, 1.5, cursor)
assert(a.id=="middle" and b.id=="last" and alpha==0.5 and not finished)
a, b, alpha, cursor, finished = Timeline.sample(frames, 2, cursor)
assert(a.id=="last" and b.id=="last" and alpha==0 and finished)
a, b, alpha = Timeline.sample(frames, 0.25, cursor)
assert(a.id=="first" and alpha==0.25)
a, b, alpha, cursor, finished = Timeline.sample({{time=0,id="only"}}, 1)
assert(a.id=="only" and b==a and finished)
a, b, alpha, cursor, finished = Timeline.sample({}, 0)
assert(a==nil and b==nil and finished)
local repeated={{time=0,id=1},{time=0,id=2},{time=1,id=3}}
assert(Timeline.sample(repeated,0).id==2)
assert(Timeline.speed(0)==0.1 and Timeline.speed(100)==20)
assert(Timeline.speed(0/0)==1 and Timeline.speed(math.huge)==1 and Timeline.speed("fast",2)==2)
assert(Timeline.eventModifier("")==1 and Timeline.eventModifier("No events")==1)
assert(math.abs(Timeline.eventModifier('<font color="#ff0000">Speed Up</font>')-1/1.1225)<1e-10)
assert(math.abs(Timeline.eventModifier("Slowdown / Speedup")-1/(1.1225*(1-0.1091)))<1e-10)
local states={{"initial"},{"one","two"},{},{"three"}}
local buffer={"four","five"}
local frame
assert(Buffer.count(states,buffer)==6)
for _, expected in ipairs({"four","three","two","one","initial","initial"}) do
    buffer,frame=Buffer.rewind(states,buffer)
    assert(frame==expected, tostring(frame).." ~= "..expected)
end
assert(#states==1 and #buffer==0 and Buffer.count(states,buffer)==1)
print("PASS: TAS first/final/single-frame interpolation, speed event reset, and checkpoint-boundary rewind")
