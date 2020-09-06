---------------------------------------------------------------
-- Mouse state handler
---------------------------------------------------------------
-- Used to control mouse state depending on different scenarios
-- and allows customization to how the mouse and camera should
-- behave.

local _, db = ...;
local ESCAPE_KEY, Mouse = {}, CPAPI.CreateEventHandler({'Frame', '$parentMouseHandler', ConsolePort}, {
	'UPDATE_BINDINGS';
})

---------------------------------------------------------------
-- Upvalues since these will be called/checked frequently
---------------------------------------------------------------
local GameTooltip, UIParent, WorldFrame = GameTooltip, UIParent, WorldFrame;
local GetCVar, GetCVarBool, SetCVar = GetCVar, GetCVarBool, SetCVar;
local CreateKeyChordString = CreateKeyChordStringUsingMetaKeyState;
local UnitExists, GetMouseFocus = UnitExists, GetMouseFocus;
local NewTimer = C_Timer.NewTimer;

---------------------------------------------------------------
-- Helpers: predicate evaluators
---------------------------------------------------------------
-- These functions are used to write clear, dynamic statements
-- on combinations of different events. Without these, compound
-- boolean expressions would be hard to understand.
-- Args: button ID, followed by list of predicates.

local function is(_, pred, ...)
	if pred == nil then return true end
	return pred(_) and is(_, ...)
end

local function isnt(...)
	return not is(...)
end

local function either(_, pred,  ...)
	if pred == nil then return end
	return pred(_) or either(_, ...)
end


function Mouse:UPDATE_BINDINGS()
	wipe(ESCAPE_KEY)
	for _, binding in ipairs({db('Gamepad'):GetBindingKey('TOGGLEGAMEMENU')}) do
		ESCAPE_KEY[binding] = true
	end
end

---------------------------------------------------------------
-- Timer
---------------------------------------------------------------
function Mouse:SetTimer(callback, time)
	self:ClearTimer(callback)
	if ( time > 0 ) then
		self[callback] = NewTimer(time, function()
			callback(self)
		end)
	end
end

function Mouse:ClearTimer(callback)
	if self[callback] then
		self[callback]:Cancel()
		self[callback] = nil;
	end
end

---------------------------------------------------------------
-- Predicate evaluators (should always return boolean)
---------------------------------------------------------------
local CameraControl  = IsGamePadFreelookEnabled;
local CursorControl  = IsGamePadCursorControlEnabled;
local MenuFrameOpen  = IsOptionFrameOpen;
local SpellTargeting = SpellIsTargeting;
local LeftClick      = function(button) return button == GetCVar('GamePadCursorLeftClick') end;
local RightClick     = function(button) return button == GetCVar('GamePadCursorRightClick') end;
local MenuBinding    = function(button) return ESCAPE_KEY[CreateKeyChordString(button)] end;
local CursorCentered = function() return GetCVarBool('GamePadCursorCentering') end;
local TooltipShowing = function() return GameTooltip:IsOwned(UIParent) and GameTooltip:GetAlpha() == 1 end;
local WorldInteract  = function() return TooltipShowing() and GetMouseFocus() == WorldFrame end;
local MouseOver      = function() return UnitExists('mouseover') or WorldInteract() end;

---------------------------------------------------------------
-- Compounded queries:
---------------------------------------------------------------
function Mouse:ShouldSetCenteredCursor(_)
	return is(_, RightClick, CameraControl) and isnt(_, CursorCentered)
end

function Mouse:ShouldClearCenteredCursor(_)
	return is(_, RightClick, CameraControl, CursorCentered) and isnt(_, MouseOver)
end

function Mouse:ShouldFreeCenteredCursor(_)
	return is(_, MenuBinding, CameraControl, CursorCentered) and isnt(_, MouseOver)
end

function Mouse:ShouldSetCursorWhenMenuIsOpen(_)
	return is(_, MenuBinding, MenuFrameOpen) and isnt(_, CursorControl)
end

function Mouse:ShouldSetFreeCursor(_)
	return is(_, LeftClick) and isnt(_, SpellTargeting) and either(_, CameraControl, CursorCentered)
end

---------------------------------------------------------------
-- Base control functions: (there seems to be bugs with these API functions)
---------------------------------------------------------------
function Mouse:SetCentered(enabled)
	SetCVar('GamePadCursorCentering', enabled)
	return self
end

function Mouse:SetCursorControl(enabled)
	SetGamePadCursorControl(enabled)
	return self
end

function Mouse:SetFreeLook(enabled)
	SetGamePadFreeLook(enabled)
	return self
end

function Mouse:SetPropagation(enabled)
	self:SetPropagateKeyboardInput(enabled)
	return self
end

---------------------------------------------------------------
-- Compounded control functions:
---------------------------------------------------------------
function Mouse:SetFreeCursor()
	return self
		:SetCentered(false)
		:SetFreeLook(false)
		:SetCursorControl(true)
end

function Mouse:SetCenteredCursor()
	self:SetTimer(self.ClearCenteredCursor, db('mouseAutoClearCenter'))
	return self
		:SetCentered(true)
		:SetFreeLook(false)
		:SetCursorControl(false)
end

function Mouse:ClearCenteredCursor()
	self:ClearTimer(self.ClearCenteredCursor)
	if db('mouseAlwaysCentered') then return self end
	return self
		:SetCentered(false)
		:SetFreeLook(false)
		:SetCursorControl(false)
end

---------------------------------------------------------------
-- Handlers
---------------------------------------------------------------
function Mouse:OnGamePadButtonDown(button)
	if self:ShouldSetFreeCursor(button) then
		return self:SetFreeCursor()
	end
	-- TODO: check bugs with blizz, expand on concept
	if self:ShouldSetCenteredCursor(button) then
		return self:SetCenteredCursor()
	end
	if self:ShouldClearCenteredCursor(button) then
		return self:ClearCenteredCursor()
	end--[[
	if self:ShouldFreeCenteredCursor(button) then
		return self:SetCentered(false):SetCursorControl(true)
	end
	if self:ShouldSetCursorWhenMenuIsOpen(button) then
		return self:SetPropagation(false):SetCursorControl(true)
	end]]
	return self:SetPropagation(true)
end

function Mouse:OnGamePadButtonUp(button)
	-- TODO: check usefulness
	return self:SetPropagation(true)
end

---------------------------------------------------------------
-- Handler on/off
---------------------------------------------------------------
function Mouse:SetEnabled(enabled)
	self:EnableGamePadButton(enabled)
	if enabled then
		SetCVar('GamePadCursorAutoEnable', 0)
	end
end

function Mouse:OnDataLoaded()
	self:SetEnabled(db('mouseHandlingEnabled'))
end

db:RegisterVarCallback('Settings/mouseHandlingEnabled', Mouse.SetEnabled, Mouse)
CPAPI.Start(Mouse)
Mouse:EnableGamePadButton(false)
Mouse:SetPropagation(true)