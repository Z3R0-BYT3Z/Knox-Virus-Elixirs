package.path = TEST_LUA_PATH .. ";" .. package.path
CLIENT, SERVER, CLOCK = false, true, 100
function isClient() return CLIENT end
function isServer() return SERVER end
function getGameTime() return { getWorldAgeHours = function() return CLOCK end } end
function getTimestampMs() return CLOCK * 3600000 end
function instanceof(value, kind) return kind == "IsoPlayer" and value.isPlayer == true end
function getText(key, ...) return key end
function getTextOrNull(key) return key end
function ZombRand() return 9999 end
SandboxVars = { ElixirCraftB42 = {EnableAntibodiesIntegration = false} }
local opts = SandboxVars.ElixirCraftB42
local records = {}
ModData = { getOrCreate = function(key) records[key] = records[key] or {}; return records[key] end }
MESSAGES, REMOVED, ADDED = {}, 0, 0
function sendServerCommand(a,b,c,d)
    table.insert(MESSAGES, {player=a,command=c,args=d})
end
function sendClientCommand() end
function sendRemoveItemFromContainer() REMOVED = REMOVED + 1 end
function sendAddItemToContainer() ADDED = ADDED + 1 end
Events = setmetatable({}, {__index = function(t,k)
    local e = { callbacks = {} }
    function e.Add(f) table.insert(e.callbacks, f) end
    rawset(t,k,e); return e
end})
local function list(values)
    return { size=function() return #values end, get=function(_,i) return values[i+1] end }
end
local function inventory(parent)
    local c = { items={}, parent=parent }
    function c:getItems() return list(self.items) end
    function c:getContainingItem() return self.parent end
    function c:contains(item)
        for _,v in ipairs(self.items) do if v==item then return true end end
        return false
    end
    function c:AddItem(item) table.insert(self.items,item); item.container=self; return item end
    function c:Remove(item)
        for i,v in ipairs(self.items) do if v==item then table.remove(self.items,i); item.container=nil; return end end
    end
    return c
end
local nextItem=0
local function item(c,typ)
    nextItem=nextItem+1
    local i={container=c, fullType=typ or "ElixirCraft.KnoxCure", id=nextItem}
    function i:getContainer() return self.container end
    function i:getFullType() return self.fullType end
    function i:getID() return self.id end
    c:AddItem(i); return i
end
local function square(x,y,z)
    local s={x=x or 10,y=y or 10,z=z or 0,blocked=false,window=false,objects={}}
    function s:getX() return self.x end
    function s:getY() return self.y end
    function s:getZ() return self.z end
    function s:isBlockedTo() return self.blocked end
    function s:isWindowTo() return self.window end
    function s:getObjects() return list(self.objects) end
    return s
end
local function part(health,bitten)
    local p={health=health or 50,bite=bitten or false,restored=0}
    function p:getHealth() return self.health end
    function p:setHealth(v) self.health=v end
    function p:AddHealth(v) self.health=self.health+v end
    function p:bitten() return self.bite end
    function p:RestoreToFullHealth() self.health=100; self.restored=self.restored+1; self.bite=false end
    function p:SetBitten(v) self.bite=v end
    function p:setBiteTime() end
    function p:SetInfected() end
    function p:setWoundInfectionLevel() end
    return p
end
local id=0
local function player(role)
    id=id+1
    local p={isPlayer=true,md={},inv=inventory(),sq=square(10,9,0),dead=false,role=role or "none",id=id}
    local damage={parts={part(50,true),part(60,false)},health=55,infected=true}
    function damage:getBodyParts() return list(self.parts) end
    function damage:calculateOverallHealth() self.health=(self.parts[1].health+self.parts[2].health)/2 end
    function damage:getOverallBodyHealth() return self.health end
    function damage:setOverallBodyHealth(v) self.health=v end
    function damage:setInfected(v) self.infected=v end
    function damage:setInfectionTime() end
    function damage:setInfectionMortalityDuration() end
    function damage:RestoreToFullHealth()
        for _,bp in ipairs(self.parts) do bp:RestoreToFullHealth() end
        self.health=100
    end
    p.damage=damage
    local stats={Endurance=.2,Fatigue=.8,Panic=0,Stress=0,Thirst=.2,Hunger=.9}
    for _,name in ipairs({'Endurance','Fatigue','Panic','Stress','Thirst','Hunger'}) do
        stats['get'..name]=function(self) return self[name] end
        stats['set'..name]=function(self,v) self[name]=v end
    end
    function stats:setEnduranceRecharging() end
    local nutrition = {calories=-1000}
    function nutrition:getCalories() return self.calories end
    function nutrition:setCalories(v) self.calories=v end
    function p:getNutrition() return nutrition end
    function p:getStats() return stats end
    function p:getModData() return self.md end
    function p:getInventory() return self.inv end
    function p:getCurrentSquare() return self.sq end
    function p:getVehicle() return self.vehicle end
    function p:getBodyDamage() return self.damage end
    function p:getAccessLevel() return self.role end
    function p:isDead() return self.dead end
    function p:getOnlineID() return self.id end
    function p:getPlayerNum() return 0 end
    function p:getUsername() return 'tester'..self.id end
    function p:getDisplayName() return self:getUsername() end
    function p:getX() return self.sq.x end
    function p:getY() return self.sq.y end
    function p:getZ() return self.sq.z end
    function p:Say() end
    function p:faceThisObject() end
    function p:shouldBeTurning() return false end
    function p:SetVariable() end
    return p
end
local function object()
    local o={sq=square(),md={},index=1}
    local props={get=function(_,key) return key=='CustomName' and 'Well' or nil end, has=function() return false end}
    local sprite={getName=function() return 'test_well' end,getProperties=function() return props end}
    function o:getSquare() return self.sq end
    function o:getObjectIndex() return self.index end
    function o:getModData() return self.md end
    function o:getSprite() return sprite end
    function o:transmitModData() self.synced=(self.synced or 0)+1 end
    table.insert(o.sq.objects,o)
    return o
end
package.preload['TimedActions/ISBaseTimedAction']=function()
    ISBaseTimedAction={}
    function ISBaseTimedAction:derive(name)
        local c={}; c.__index=c; setmetatable(c,{__index=self}); return c
    end
    function ISBaseTimedAction.new(self,p) return setmetatable({character=p},{__index=self}) end
    function ISBaseTimedAction:perform() end
    function ISBaseTimedAction:setActionAnim() end
    function ISBaseTimedAction:setAnimVariable() end
    function ISBaseTimedAction:setOverrideHandModels() end
    return ISBaseTimedAction
end
require 'TimedActions/ISElixirAction'
require 'ElixirServer'
local admin=player('admin')
local function hello(p,protocol)
    for _,f in ipairs(Events.OnClientCommand.callbacks) do f('ElixirCraftB42','Hello',p,{protocol=protocol or 4}) end
end
local function well()
    local o=object(); assert(ElixirWell.AdminChange(admin,o,'DesignateWell')); return o
end
TEST_PASSED=0
local function test(name,f)
    opts.WellUnlimitedSupply=false;opts.WellFullRecovery=false
    opts.EnableHealingWell=true;opts.WellCooldownHours=24;opts.WellHealWounds=false
    opts.WellCuresKnox=false;opts.WellAllowPlayerRefill=true;opts.WellHealAmount=25
    opts.WellCapacity=20;opts.WellInitialCharges=5;opts.WellRefillCharges=5
    opts.CureEffectiveness=100;opts.OneCurePerCharacter=false;opts.EnableKnoxCure=true
    opts.ConsumeCureOnFailedUse=false;opts.ReturnRejectedStimulant=true
    CLIENT,SERVER=false,true
    local ok,err=pcall(f)
    assert(ok,name..': '..tostring(err)); TEST_PASSED=TEST_PASSED+1
    print('PASS '..name)
end

test('admin designation and initial charges',function()
    local o=well();local r=ElixirWell.Record(o);assert(r.charges==5 and r.capacity==20)
end)
test('non-admin cannot designate',function()
    local ok,why=ElixirWell.AdminChange(player(),object(),'DesignateWell');assert(not ok and why=='admin-only')
end)
test('moderator cannot designate',function()
    assert(not ElixirWell.AdminChange(player('moderator'),object(),'DesignateWell'))
end)
test('configured partial healing preserves bite and infection',function()
    local p,o=player(),well();assert(ElixirWell.Drink(p,o));assert(p.damage.parts[1].health==75)
    assert(p.damage.parts[1].bite and p.damage.infected);assert(ElixirWell.Record(o).charges==4)
end)
test('wound restoration excludes bites',function()
    opts.WellHealWounds=true;local p=player();assert(ElixirWell.Drink(p,well()))
    assert(p.damage.parts[1].bite and p.damage.parts[1].restored==0)
    assert(p.damage.parts[2].restored==1)
end)
test('last charge can heal only one player',function()
    local o=well();ElixirWell.Record(o).charges=1
    assert(ElixirWell.Drink(player(),o));local ok,why=ElixirWell.Drink(player(),o)
    assert(not ok and why=='well-empty' and ElixirWell.Record(o).charges==0)
end)
test('well use has no cooldown across wells',function()
    local p=player();assert(ElixirWell.Drink(p,well()));local o=well()
    assert(ElixirWell.Drink(p,o));assert(ElixirWell.Record(o).charges==4)
end)
test('repeated well use has no wait',function()
    local p,o=player(),well();assert(ElixirWell.Drink(p,o));assert(ElixirWell.Drink(p,o))
end)
test('old saved well cooldown is ignored',function()
    local p=player();p.md.ElixirCraftB42={lastWellUse=CLOCK}
    assert(ElixirWell.Remaining(p)==0 and ElixirWell.Drink(p,well()))
end)
test('forged marker cannot create charges',function()
    local o=object();o.md.ElixirCraftB42Well={id='forged',charges=999}
    assert(not ElixirWell.Drink(player(),o))
end)
test('client mirror cannot change registry charges',function()
    local o=well();o.md.ElixirCraftB42Well.charges=999;assert(ElixirWell.Record(o).charges==5)
end)
test('moved registered object rejected',function()
    local o=well();o.sq.x=11;assert(ElixirWell.Record(o)==nil)
end)
test('far player rejected',function()
    local p=player();p.sq.x=30;assert(not ElixirWell.Drink(p,well()))
end)
test('different floor rejected',function()
    local p=player();p.sq.z=1;assert(not ElixirWell.Drink(p,well()))
end)
test('blocked path rejected',function()
    local p=player();p.sq.blocked=true;assert(not ElixirWell.Drink(p,well()))
end)
test('window path rejected',function()
    local p=player();p.sq.window=true;assert(not ElixirWell.Drink(p,well()))
end)
test('vehicle and dead players rejected',function()
    local p=player();p.vehicle={};assert(not ElixirWell.Drink(p,well()))
    p.vehicle=nil;p.dead=true;assert(not ElixirWell.Drink(p,well()))
end)
test('refill consumes one owned bottle',function()
    local p,o=player(),well();local i=item(p.inv);assert(ElixirWell.Refill(p,o,i))
    assert(not p.inv:contains(i) and ElixirWell.Record(o).charges==10)
    assert(not ElixirWell.Refill(p,o,i))
end)
test('full well keeps refill bottle',function()
    local p,o=player(),well();ElixirWell.Record(o).charges=20;local i=item(p.inv)
    assert(not ElixirWell.Refill(p,o,i) and p.inv:contains(i))
end)
test('refill caps capacity',function()
    local p,o=player(),well();ElixirWell.Record(o).charges=19;assert(ElixirWell.Refill(p,o,item(p.inv)))
    assert(ElixirWell.Record(o).charges==20)
end)
test('foreign inventory bottle rejected',function()
    local p=player();assert(not ElixirWell.Refill(p,well(),item(inventory())))
end)
test('nested owned bottle accepted',function()
    local p=player();local bag=item(p.inv,'Base.Bag');local inv=inventory(bag);local i=item(inv)
    assert(ElixirConsumption.OwnsItem(p,i,'ElixirCraft.KnoxCure'))
end)
test('disabled player refill enforced',function()
    opts.WellAllowPlayerRefill=false;local p=player();assert(not ElixirWell.Refill(p,well(),item(p.inv)))
end)
test('admin recharge and removal',function()
    local o=well();assert(ElixirWell.AdminChange(admin,o,'AdminRechargeWell'));assert(ElixirWell.Record(o).charges==20)
    assert(ElixirWell.AdminChange(admin,o,'RemoveWell'));assert(not ElixirWell.Record(o))
end)
test('disabled well does not consume a charge',function()
    local o=well();opts.EnableHealingWell=false;assert(not ElixirWell.Drink(player(),o));assert(ElixirWell.Record(o).charges==5)
end)
test('registry survives module reload',function()
    local o=well();assert(ElixirWell.Drink(player(),o));package.loaded.ElixirWell=nil;require 'ElixirWell'
    assert(ElixirWell.Record(o).charges==4)
end)
test('optional well cure restores health and infection',function()
    opts.WellCuresKnox=true;local p=player();assert(ElixirWell.Drink(p,well()))
    assert(not p.damage.infected and not p.damage.parts[1].bite)
end)
test('one-cure bottle policy does not restrict well',function()
    opts.WellCuresKnox=true;opts.OneCurePerCharacter=true;local p,o=player(),well()
    p.md.ElixirCraftB42={successfulKnoxCure=true};assert(ElixirWell.Drink(p,o));assert(ElixirWell.Record(o).charges==4)
end)
test('well cure has no bottle effectiveness roll',function()
    opts.WellCuresKnox=true;opts.CureEffectiveness=1;local p=player()
    local ok,_,d=ElixirWell.Drink(p,well());assert(ok and d.curedKnox and not p.damage.infected)
    assert(p.damage.parts[1].health==100)
end)
test('bottle action cannot complete twice',function()
    local p=player();hello(p);local i=item(p.inv);local a=ISElixirAction:new(p,'KnoxCure',nil,i,4)
    a:complete();local count=REMOVED;a:complete();assert(REMOVED==count and not p.inv:contains(i))
end)
test('same bottle cannot be replayed in another action',function()
    local p=player();hello(p);local i=item(p.inv);ISElixirAction:new(p,'KnoxCure',nil,i,4):complete()
    local count=REMOVED;ISElixirAction:new(p,'KnoxCure',nil,i,4):complete();assert(REMOVED==count)
end)
test('unhandshaken action rejected',function()
    local p=player();local i=item(p.inv);ISElixirAction:new(p,'KnoxCure',nil,i,4):complete();assert(p.inv:contains(i))
end)
test('old protocol rejected',function()
    local p=player();hello(p,3);local i=item(p.inv);ISElixirAction:new(p,'KnoxCure',nil,i,3):complete();assert(p.inv:contains(i))
end)
test('old instant command cannot treat',function()
    local p=player();hello(p);local i=item(p.inv)
    for _,f in ipairs(Events.OnClientCommand.callbacks) do f('ElixirCraftB42','UseTreatment',p,{itemId=i.id}) end
    assert(p.inv:contains(i) and p.damage.infected)
end)
test('failed cure refunded once when configured',function()
    opts.CureEffectiveness=1;local p=player();local i=item(p.inv);local before=ADDED
    assert(not ElixirConsumption.CommitBottle(p,i,'KnoxCure'));assert(p.inv:contains(i) and ADDED==before+1)
end)
test('failed cure consumed when configured',function()
    opts.CureEffectiveness=1;opts.ConsumeCureOnFailedUse=true;local p=player();local i=item(p.inv)
    assert(not ElixirConsumption.CommitBottle(p,i,'KnoxCure'));assert(not p.inv:contains(i))
end)
test('cooldown rejection keeps default cure',function()
    local p=player();p.md.ElixirCraftB42={lastKnoxCureUse=CLOCK};local i=item(p.inv)
    assert(not ElixirConsumption.CommitBottle(p,i,'KnoxCure'));assert(p.inv:contains(i))
end)
test('rejected stimulant consumption policy',function()
    local p=player();p.md.ElixirCraftB42={lastAdrenalineUse=CLOCK};local i=item(p.inv,'ElixirCraft.StaminaElixir')
    assert(not ElixirConsumption.CommitBottle(p,i,'AdrenalineStimulant'));assert(p.inv:contains(i))
    opts.ReturnRejectedStimulant=false;assert(not ElixirConsumption.CommitBottle(p,i,'AdrenalineStimulant'))
    assert(not p.inv:contains(i))
end)
test('single-player bottle effect and failure handling',function()
    SERVER=false;local p=player();local i=item(p.inv,'ElixirCraft.StaminaElixir')
    assert(ElixirConsumption.CommitBottle(p,i,'AdrenalineStimulant'));assert(p:getStats():getEndurance()==1)
    local next=item(p.inv,'ElixirCraft.StaminaElixir');assert(not ElixirConsumption.CommitBottle(p,next,'AdrenalineStimulant'))
    assert(p.inv:contains(next))
end)
test('stimulant crash delivered once',function()
    local p=player();assert(ElixirConsumption.CommitBottle(p,item(p.inv,'ElixirCraft.StaminaElixir'),'AdrenalineStimulant'))
    CLOCK=CLOCK+1;assert(ElixirConsumption.ProcessPostCrash(p));assert(not ElixirConsumption.ProcessPostCrash(p))
end)
test('treatment exception cannot refund partially applied effect',function()
    local p=player();local i=item(p.inv);local original=ElixirConsumption.ApplyTreatment
    ElixirConsumption.ApplyTreatment=function() error('simulated mutation error') end
    assert(not ElixirConsumption.CommitBottle(p,i,'KnoxCure'));assert(not p.inv:contains(i))
    ElixirConsumption.ApplyTreatment=original
end)
test('client complete cannot mutate well',function()
    local o,p=well(),player();local a=ISElixirAction:new(p,'DrinkWell',o,nil,4);CLIENT=true;SERVER=false
    a:complete();CLIENT=false;assert(ElixirWell.Record(o).charges==5)
end)

test('client healing confirmation is idempotent',function()
    local p=player();CLIENT=true;SERVER=false
    local d={partHealth={75,85},healthAfter=80,usedAt=CLOCK,charges=4,healWounds=false}
    ElixirConsumption.HandleResult('WellApplied',d,p)
    ElixirConsumption.HandleResult('WellApplied',d,p)
    assert(p.damage.parts[1].health==75 and p.damage.parts[2].health==85)
    assert(p.damage.infected and p.damage.parts[1].bite)
end)
test('server result targets correct local player',function()
    local p0,p1=player(),player();CLIENT=true;SERVER=false
    function getNumActivePlayers() return 2 end
    function getSpecificPlayer(n) return n==0 and p0 or p1 end
    ElixirConsumption.HandleResult('WellApplied',{playerOnlineID=p1.id,partHealth={80,90},healthAfter=85,charges=3})
    assert(p0.damage.parts[1].health==50 and p1.damage.parts[1].health==80)
end)
test('single-player full cure is not applied twice',function()
    SERVER=false;opts.CureTreatmentScope=4;local p=player()
    assert(ElixirConsumption.CommitBottle(p,item(p.inv),'KnoxCure'))
    assert(p.damage.parts[1].restored==2) -- scope 3 restores once, scope 4 once
    opts.CureTreatmentScope=nil
end)
test('cancelled action makes no changes',function()
    local p,o=player(),well();hello(p);ISElixirAction:new(p,'DrinkWell',o,nil,4):perform()
    assert(ElixirWell.Record(o).charges==5 and p.damage.parts[1].health==50)
end)
test('different sprite cannot impersonate a registered well',function()
    local o=well();o.getSprite=function() return {getName=function() return 'fake' end} end
    assert(ElixirWell.Record(o)==nil)
end)

-- UI smoke test with the same callback/argument convention as the game.
package.preload['TimedActions/ISTimedActionQueue']=function()
    ISTimedActionQueue={add=function(action) LAST_ACTION=action end};return ISTimedActionQueue
end
package.preload['ISUI/ISWorldObjectContextMenu']=function() return {} end
luautils={walkAdjObject=function() return true end}
local function context()
    local c={options={}}
    function c:addOption(label,target,callback,...)
        local option={label=label,target=target,callback=callback,args={...}}
        table.insert(self.options,option);return option
    end
    function c:addSubMenu(root,sub) root.submenu=sub end
    return c
end
ISContextMenu={getNew=function() return context() end}
CLIENT,SERVER=true,false
require 'ElixirMenus'
ElixirConsumption.SetProtocolState(true,false)

test('inventory context menu queues correct native action',function()
    CLIENT=true;SERVER=false;local p=player();function getSpecificPlayer() return p end
    local i=item(p.inv);local c=context()
    for _,f in ipairs(Events.OnFillInventoryObjectContextMenu.callbacks) do f(0,c,{{items={i}}}) end
    assert(#c.options==1)
    local option=c.options[1];option.callback(option.target,unpack(option.args,1,4))
    assert(LAST_ACTION.operation=='KnoxCure' and LAST_ACTION.item==i and LAST_ACTION.protocol==4)
end)
test('well menu scans full clicked square',function()
    local o=well();local p=player('admin');CLIENT=true;SERVER=false
    function getSpecificPlayer() return p end
    local c=context()
    for _,f in ipairs(Events.OnFillWorldObjectContextMenu.callbacks) do f(0,c,{o},false) end
    assert(c.options[1].submenu and #c.options[1].submenu.options>=5)
end)
test('single-player existing water source offers designation',function()
    SERVER=false;local p=player();function getSpecificPlayer() return p end
    local o,c=object(),context()
    for _,f in ipairs(Events.OnFillWorldObjectContextMenu.callbacks) do f(0,c,{o},false) end
    assert(c.options[1].args[1]=='DesignateWell')
end)


test('unlimited fully recovered well repeats without depletion',function()
    opts.WellUnlimitedSupply=true;opts.WellFullRecovery=true
    local p,o=player(),well();ElixirWell.Record(o).charges=0
    assert(ElixirWell.Drink(p,o));assert(p.damage:getOverallBodyHealth()==100)
    assert(not p.damage.infected and not p.damage.parts[1].bite)
    p.damage.parts[1].health=10;p.damage.infected=true;p.damage.parts[1].bite=true
    assert(ElixirWell.Drink(p,o));assert(ElixirWell.Record(o).charges==0)
    assert(p.damage.parts[1].health==100 and not p.damage.infected and not p.damage.parts[1].bite)
end)
test('full recovery ignores disabled bottle and cure cooldown',function()
    opts.WellUnlimitedSupply=true;opts.WellFullRecovery=true
    opts.EnableKnoxCure=false;opts.OneCurePerCharacter=true;opts.CureEffectiveness=1
    local p=player();p.md.ElixirCraftB42={lastKnoxCureUse=CLOCK,lastAdrenalineUse=CLOCK,successfulKnoxCure=true}
    assert(ElixirWell.Drink(p,well()));assert(p.damage:getOverallBodyHealth()==100 and not p.damage.infected)
    assert(p.md.ElixirCraftB42.lastKnoxCureUse==CLOCK and p.md.ElixirCraftB42.lastAdrenalineUse==CLOCK)
end)
test('unlimited refill rejected without spending bottle',function()
    opts.WellUnlimitedSupply=true;local p,o=player(),well();local i=item(p.inv)
    assert(not ElixirWell.Refill(p,o,i));assert(p.inv:contains(i))
end)
test('unlimited full recovery menu hides refills and charges',function()
    opts.WellUnlimitedSupply=true;opts.WellFullRecovery=true;local o=well()
    local p=player('admin');CLIENT=true;SERVER=false;function getSpecificPlayer() return p end
    local c=context();for _,f in ipairs(Events.OnFillWorldObjectContextMenu.callbacks) do f(0,c,{o},false) end
    local labels={};for _,v in ipairs(c.options[1].submenu.options) do labels[v.label]=true end
    assert(labels.ContextMenu_ElixirCraft_WellUnlimited and labels.ContextMenu_ElixirCraft_WellFullRecovery)
    assert(not labels.ContextMenu_ElixirCraft_RefillWell and not labels.ContextMenu_ElixirCraft_AdminRechargeWell)
    assert(not labels.ContextMenu_ElixirCraft_WellCharges)
end)

test('full well replenishes survival stats without stimulant penalties',function()
    opts.WellUnlimitedSupply=true;opts.WellFullRecovery=true
    local p=player();p.md.ElixirCraftB42={lastAdrenalineUse=CLOCK,lastKnoxCureUse=CLOCK}
    local ok,_,d=ElixirWell.Drink(p,well());assert(ok)
    local st=p:getStats()
    assert(st:getHunger()==0 and st:getThirst()==0 and st:getFatigue()==0 and st:getEndurance()==1)
    assert(p:getNutrition():getCalories()==2500 and d.caloriesAfter==2500)
    assert(p.damage:getOverallBodyHealth()==100)
    assert(p.md.ElixirCraftB42.lastAdrenalineUse==CLOCK and p.md.ElixirCraftB42.lastKnoxCureUse==CLOCK)
end)
test('repeat well calories do not stack or reduce higher reserves',function()
    opts.WellUnlimitedSupply=true;opts.WellFullRecovery=true
    local p,o=player(),well();assert(ElixirWell.Drink(p,o));assert(ElixirWell.Drink(p,o))
    assert(p:getNutrition():getCalories()==2500)
    p:getNutrition():setCalories(3000);assert(ElixirWell.Drink(p,o))
    assert(p:getNutrition():getCalories()==3000)
end)
test('partial well leaves hunger calories and endurance unchanged',function()
    local p=player();assert(ElixirWell.Drink(p,well()))
    assert(p:getStats():getHunger()==.9 and p:getStats():getEndurance()==.2)
    assert(p:getNutrition():getCalories()==-1000)
end)
test('full well client synchronization is idempotent',function()
    local p=player();CLIENT=true;SERVER=false
    local d={fullRecovery=true,caloriesAfter=3000,unlimited=true}
    ElixirConsumption.HandleResult('WellApplied',d,p)
    ElixirConsumption.HandleResult('WellApplied',d,p)
    assert(p:getNutrition():getCalories()==3000 and p:getStats():getHunger()==0)
    assert(p:getStats():getEndurance()==1 and p:getStats():getFatigue()==0)
end)
